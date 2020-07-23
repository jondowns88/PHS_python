/*******************************************************************
*	sda_calculation.sql												
*	By: Jon Downs													
*	4/10/2020														
*	Purpose: To pull days served in SDA look-back period and total	
*			svc hours expected.										
*********************************************************************/
/*UPDATES*/
-- 4/10/2020 (JD): All pieces of the SDA query were originally one chunk.
--				The goal now is to break this down into three steps
--				to increase code clarity.

-- 5/28/2020 (JD): The 'day calculation' and 'hour calculation' are now included in the same program again. Script has been greatly simplified.
--					Numerous business rules have been implemented:
--						Service and enrollment days during suspended periods are now counted
--						SDA can extend across multiple authorizations, if the previous authorization ended at the same agency within 90 days.
--						Clients must now be enrolled for >30 days during the SDA period in order to have an SDA calculated (was 14 days of non-suspension).
--					Future work will ensure clients are enrolled for a full 'calendar month' for an SDA calculation rather than 30+ days of service during the SDA period.
--	6/3/2020 (JD): Added comments and clarity for presentation of the code at ISAC.
--  6/17/2020 (JD): One calendar month rule implemented.
/*
	Note: In production, this script is called from R using the 'glue' package. This is why users will see text such as #phs_sda instead of normal SQL syntax.
		  To run this script, users must first:
			1) Create a list of clients that need SDA calculation.
				--Include auth_no, kcid, program, and age_group (A/G/C).
				--Store these columns in a temporary table. 
				--Replace #phs_sda with the name of your temporary table, in normal SQL syntax (e.g. #my_temp).
			2) Identify the start/end dates of the SDA calculation period:
				--For Q1 stratifications, SDA runs from 9/1 - 11/30 of the prior year
				--For Q2, SDA runs from 12/1 - 2/28 (2/29 if leap year)
				--For Q3, SDA runs from 3/1 - 5/31
				--And, for Q4, SDA runs from 6/1 - 8/30
				--The start and end dates should replace the {start_date} and {end_date} variables with dates in SQL syntax (e.g. '2019-12-01' and '2020-02-29').
*/

SET NOCOUNT ON; --Helps with running queries in R.
---------------------------------------------------------
--	Set Parameters
---------------------------------------------------------
/*Declare report dates*/
DECLARE @sdate DATE, @edate DATE, @mo1_start DATE, @mo1_end DATE, @mo2_start DATE, @mo2_end DATE, @mo3_start DATE, @mo3_end DATE;
SET @sdate = :start_date; /*SDA calculation start date*/
SET @edate = :end_date; /*SDA calculation end date*/

--Calendar month calculation- set first/last days of each SDA month
SET @mo1_start = @sdate;
SET @mo1_end = EOMONTH(@sdate);
SET @mo2_start = DATEADD(m, 1, @mo1_start);
SET @mo2_end = EOMONTH(@mo2_start);
SET @mo3_start = DATEADD(m, 1, @mo2_start);
SET @mo3_end = EOMONTH(@mo3_start);

---------------------------------------------------------
--	Initialize the table								
---------------------------------------------------------
--SDA always extends across two calendar quarters. Thus, each SDA calculation can have more than one stratification during the SDA look-back. 
--For example, the Q2 2020 SDA calc will use data from 12/1/2019 - 12/31/2019 (Q4) and 1/1/2020 - 2/29/2020 (Q1). 
--So, let's start by pulling all of the LOC's that were active and the quarters in which they were active.
DROP TABLE IF EXISTS #cur_strats
SELECT a.* --Your temporary input table
, d.start_date AS auth_start --Start date from AU_MASTER
, ISNULL(d.expire_date, @edate) AS auth_expire --Expire date from AU_MASTER
, d.agency_id 
--First day LOC was active during SDA period
, CASE WHEN b.start_date < @sdate THEN @sdate
	WHEN b.start_date > @edate THEN @edate 
	ELSE b.start_date END AS sda_start
--Last day LOC was active during SDA period
, CASE WHEN b.end_date IS NULL THEN @edate 
	WHEN b.end_date > @edate THEN @edate 
	WHEN b.end_date < @sdate THEN @sdate
	ELSE b.end_date END AS sda_end
, b.strat_level --Stratification level during the period
, c.svc_hrs_req --Service hours requested (based on strat. level)
, CASE WHEN a.program IN('2X1', '3A1', '3B1', '400', '401', 'MOP') THEN 'MH'
	WHEN a.program IN('S01', 'S02', 'SOP', '500', '501') THEN 'SUD'
	ELSE '' END AS tx_focus
INTO #cur_strats
FROM  #phs_sda AS a
INNER JOIN kcrsn.au_stratum AS b ON a.auth_no = b.auth_no --Get stratifications
LEFT JOIN kcrsn.cd_stratum_tier AS c ON a.program = c.program --Get service hours requested for strata (match on program/age/LOC)
	AND b.age_group = c.age_group 
	AND b.strat_level = c.strat_level
LEFT JOIN kcrsn.au_master AS d ON a.auth_no = d.auth_no --Join to auths active during that time
	WHERE 
	(
		b.start_date BETWEEN @sdate AND @edate --Quarter began during SDA period
		OR b.end_date BETWEEN @sdate AND @edate --Quarter ended during SDA period
		OR (b.start_date <= @edate AND b.end_date >= @sdate) --Quarter contains dates in the SDA period
	)

---------------------------------------------------------
--	Update start and end dates (current auth)
---------------------------------------------------------
--Now, we need to verify that an authorization was active for the entire quarter.
--If it is not, we need to truncate the sda start/end dates to correspond to days an auth was active.
UPDATE #cur_strats
SET sda_start = CASE WHEN auth_start > @edate THEN NULL --Auth began after SDA period
					WHEN auth_expire < @sdate THEN NULL --Auth ended before SDA period
					WHEN auth_start > sda_start THEN auth_start --Auth began after quarter began (stratifications can extend beyond auth start dates)
					ELSE sda_start END, --No changes needed
	sda_end = CASE WHEN auth_start > @edate THEN NULL --Auth began after SDA period
					WHEN auth_expire < @sdate THEN NULL --Auth ended before SDA period
					WHEN auth_expire < sda_end THEN auth_expire --Auth ended before end of quarter
					ELSE sda_end END --No changes needed
FROM #cur_strats

---------------------------------------------------------
--	Get total enrollment days and service hours expected (current auth)
---------------------------------------------------------
--Next, we need to consider the service hours expected for the authorization during each period.
--First, we need to calculate the total days a client was enrolled at this authorization/LOC.
--Next, we will determine the total number of service hours expected by taking the DAILY hours expected times the total days a client was enrolled.
ALTER TABLE #cur_strats
ADD enroll_days INT
, svc_hrs_expected DEC(6,3);

--Calculate total enrollment days
UPDATE #cur_strats
SET enroll_days = CASE WHEN sda_start IS NULL THEN NULL --Bad data: auth was not active during SDA calculation period
						WHEN DATEDIFF(d, sda_start, sda_end) + 1 < 0 THEN NULL --Bad data: negative days mean no enrollment during SDA period
						ELSE DATEDIFF(d, sda_start, sda_end) + 1 END --Client enrolled at least 1 day at this LOC during SDA period

--Calculate total expected service hours
UPDATE #cur_strats
SET svc_hrs_expected = ISNULL(enroll_days*(svc_hrs_req/30.0), 0) --Expected service hours during the entirety of the period (prorated)

---------------------------------------------------------
--	Gather services (current auth)
---------------------------------------------------------
--Next, let's pull the number of services delivered to each auth during the SDA calculation period
ALTER TABLE #cur_strats
ADD svc_hrs DEC(6,3);

--Pull service codes in SDA period
WITH payTemp AS(
	SELECT auth_no
	, event_date
	, SUM(CASE WHEN service_minutes < 0 THEN 0 ELSE service_minutes/60.0 END) AS svc_hrs
	FROM kcrsn.ea_cpt_service
	WHERE source_id NOT IN(3, 6, 7, 8)
		AND auth_no IN(SELECT DISTINCT auth_no FROM #cur_strats) --In the group of auths we are calculating
		AND event_date BETWEEN @sdate AND @edate --Within the SDA period
		AND service_minutes > 0 --Don't include negative service minutes
	GROUP BY auth_no, event_date
),
--Summarize service hours by stratification period
service_sums AS(
	SELECT a.auth_no
	, a.sda_start
	, a.sda_end
	, SUM(COALESCE(b.svc_hrs, 0)) AS svc_hrs
	FROM #cur_strats AS a
	LEFT JOIN payTemp AS b ON a.auth_no = b.auth_no --Same auth
		AND b.event_date BETWEEN sda_start AND sda_end --Within time period
	GROUP BY a.auth_no, a.sda_start, a.sda_end
)
--Update main table with results	
UPDATE #cur_strats
SET svc_hrs = COALESCE(b.svc_hrs, 0)
FROM #cur_strats AS a LEFT JOIN service_sums AS b ON
	a.auth_no = b.auth_no --Same auth
	AND a.sda_start = b.sda_start --Same quarter
	AND a.sda_end = b.sda_end

---------------------------------------------------------
--	Create total service hours expected for the entire period (current auth)
---------------------------------------------------------
--To this point, we have allowed >1 rows per authorization, one per stratification level
--So, let's sum up enrollment days and service hours expected for each client across the entire SDA period.
DROP TABLE IF EXISTS #cur_sums;
SELECT kcid
, auth_no
, auth_start
, auth_expire
, agency_id
, program
, age_group
, tx_focus
, SUM(COALESCE(enroll_days, 0)) AS enroll_days
, SUM(svc_hrs_expected) AS svc_hrs_expected
, SUM(COALESCE(svc_hrs, 0)) AS svc_hrs
INTO #cur_sums
FROM #cur_strats
GROUP BY kcid, auth_no, auth_start, auth_expire, agency_id, program, age_group, tx_focus

---------------------------------------------------------
--	Find continuing authorization numbers
---------------------------------------------------------
--SDA can consider data from prior authorizations active during the SDA period as long as:
	--The prior auth was active during the SDA period
	--The prior auth was held by the same agency
	--The prior auth was in the same treatment focus (MH/SUD) as the current auth
	--The prior auth ended within 90 days of the current auth beginning
--So, let's identify those prior auths
ALTER TABLE #cur_sums
ADD prev_auth_no INT
, prev_auth_start DATE
, prev_auth_expire DATE;

UPDATE #cur_sums
SET prev_auth_no = b.prev_auth_no
, prev_auth_start = b.prev_auth_start
, prev_auth_expire = b.prev_auth_expire
FROM #cur_sums AS a
LEFT JOIN
(
	SELECT kcid
	, auth_no AS prev_auth_no
	, start_date AS prev_auth_start
	, expire_date AS prev_auth_expire
	, CASE WHEN program IN('2X1', '3A1', '3B1', '400', '401', 'MOP') THEN 'MH'
		WHEN program IN('S01', 'S02', 'SOP', '500', '501') THEN 'SUD'
		ELSE '' END AS tx_focus
	, agency_id
	FROM kcrsn.au_master
	WHERE status_code IN('AA', 'TM')
		AND kcid IN(SELECT kcid FROM #cur_sums) --To speed things up, only take KCIDs in our list
) AS b
ON a.kcid = b.kcid --Same client
	AND a.agency_id = b.agency_id --Same agency
	AND a.tx_focus = b.tx_focus --Same TX focus
	AND a.auth_no != b.prev_auth_no --Different auth no
	AND DATEDIFF(d, b.prev_auth_expire, a.auth_start) BETWEEN 0 AND 90 --Prior auth ended within 90 days of new auth
	AND b.prev_auth_expire >= @sdate --Prior auth ended after SDA period began

---------------------------------------------------------
--	Get tiering for prior authorizations
---------------------------------------------------------
--At this point, we're just repeating the service hours expected/delivered calculations, but for continuing benefits.
--Much of the logic will be the same as before.
DROP TABLE IF EXISTS #prev_strats
SELECT a.kcid
, a.auth_no
, a.prev_auth_no
, a.tx_focus
, a.prev_auth_start
, a.prev_auth_expire
, CASE WHEN b.start_date < @sdate THEN @sdate 
	WHEN b.start_date > @edate THEN @edate
	ELSE b.start_date END AS prev_sda_start
, CASE WHEN b.end_date IS NULL THEN @edate 
	WHEN b.end_date > @edate THEN @edate 
	WHEN b.end_date < @sdate THEN @sdate
	ELSE b.end_date END AS prev_sda_end
, b.strat_level AS prev_strat_level
, c.svc_hrs_req AS prev_svc_hrs_req
INTO #prev_strats
FROM #cur_sums AS a
INNER JOIN kcrsn.au_stratum AS b ON a.prev_auth_no = b.auth_no
LEFT JOIN kcrsn.cd_stratum_tier AS c ON a.program = c.program
	AND b.age_group = c.age_group
	AND b.strat_level = c.strat_level
WHERE 
	(
		b.start_date BETWEEN @sdate AND @edate
		OR b.end_date BETWEEN @sdate AND @edate
		OR b.start_date <= @edate AND b.end_date >= @sdate
	)
	AND a.prev_auth_no IS NOT NULL

---------------------------------------------------------
--	Update start and end dates (prior auth)
---------------------------------------------------------
UPDATE #prev_strats
SET prev_sda_start = CASE WHEN prev_auth_start > @edate THEN NULL --Auth began after SDA period
					WHEN prev_auth_expire < @sdate THEN NULL --Auth ended before SDA period
					WHEN prev_auth_start > prev_sda_start THEN prev_auth_start --Auth began after quarter began
					ELSE prev_sda_start END, --No change needed to dates of enrollment
	prev_sda_end = CASE WHEN prev_auth_start > @edate THEN NULL --Auth began after SDA period
					WHEN prev_auth_expire < @sdate THEN NULL --Auth ended before SDA period
					WHEN prev_auth_expire < prev_sda_end THEN prev_auth_expire --Auth began after quarter began
					ELSE prev_sda_end END --No change needed to dates of enrollment
FROM #prev_strats

---------------------------------------------------------
--	Get total enrollment days and service hours expected (prior auth)
---------------------------------------------------------
ALTER TABLE #prev_strats
ADD prev_enroll_days INT
, prev_svc_hrs_expected DEC(6,3);

--Calculate total enrollment days
UPDATE #prev_strats
SET prev_enroll_days = CASE WHEN prev_sda_start IS NULL THEN NULL --Bad data: auth was not active during SDA calculation period
						WHEN DATEDIFF(d, prev_sda_start, prev_sda_end) + 1 < 0 THEN NULL
						ELSE DATEDIFF(d, prev_sda_start, prev_sda_end) + 1 END --Client enrolled at least 1 day at this LOC during SDA period

--Calculate total expected service hours
UPDATE #prev_strats
SET prev_svc_hrs_expected = ISNULL(prev_enroll_days*(prev_svc_hrs_req/30.0), 0)

---------------------------------------------------------
--	Gather services (prior auth)
---------------------------------------------------------
--Next, let's pull the number of services delivered to each auth during the SDA calculation period
ALTER TABLE #prev_strats
ADD prev_svc_hrs DEC(6,3);

WITH payTemp AS(
	SELECT auth_no
	, event_date
	, SUM(CASE WHEN service_minutes < 0 THEN 0 ELSE service_minutes/60.0 END) AS prev_svc_hrs
	FROM kcrsn.ea_cpt_service
	WHERE source_id NOT IN(3, 6, 7, 8)
		AND auth_no IN(SELECT DISTINCT prev_auth_no FROM #prev_strats) --In the group of auths we are calculating
		AND event_date BETWEEN @sdate AND @edate --Within the SDA period
		AND service_minutes > 0 --Don't include negative service minutes
	GROUP BY auth_no, event_date
),
service_sums AS(
	SELECT a.prev_auth_no
	, a.prev_sda_start
	, a.prev_sda_end
	, SUM(COALESCE(b.prev_svc_hrs, 0)) AS prev_svc_hrs
	FROM #prev_strats AS a
	LEFT JOIN payTemp AS b ON a.prev_auth_no = b.auth_no
		AND b.event_date BETWEEN prev_sda_start AND prev_sda_end
	GROUP BY a.prev_auth_no, a.prev_sda_start, a.prev_sda_end
)	
UPDATE #prev_strats
SET prev_svc_hrs = COALESCE(b.prev_svc_hrs, 0)
FROM #prev_strats AS a LEFT JOIN service_sums AS b ON
	a.prev_auth_no = b.prev_auth_no
	AND a.prev_sda_start = b.prev_sda_start
	AND a.prev_sda_end = b.prev_sda_end

---------------------------------------------------------
--	Create total service hours expected for the entire period (prior auth)
---------------------------------------------------------
DROP TABLE IF EXISTS #prev_sums;
SELECT kcid
, auth_no
, prev_auth_no
, SUM(COALESCE(prev_enroll_days, 0)) AS prev_enroll_days
, SUM(prev_svc_hrs_expected) AS prev_svc_hrs_expected
, SUM(COALESCE(prev_svc_hrs, 0)) AS prev_svc_hrs
INTO #prev_sums
FROM #prev_strats
GROUP BY kcid, auth_no, prev_auth_no

---------------------------------------------------------
--	Join prior and current auth utilization data
---------------------------------------------------------
ALTER TABLE #cur_sums
ADD prev_enroll_days INT
, prev_svc_hrs_expected DEC(6,3)
, prev_svc_hrs DEC(6, 3);

UPDATE #cur_sums
SET prev_enroll_days = b.prev_enroll_days
, prev_svc_hrs_expected = b.prev_svc_hrs_expected
, prev_svc_hrs = b.prev_svc_hrs
FROM #cur_sums AS a
LEFT JOIN #prev_sums AS b
ON a.kcid = b.kcid 
	AND a.auth_no = b.auth_no
	AND a.prev_auth_no = b.prev_auth_no

---------------------------------------------------------
--	Check that benefits were open for a calendar month during SDA period
---------------------------------------------------------
ALTER TABLE #cur_sums
ADD calendar_month INT;
WITH temp_1 AS (
	SELECT kcid
	, auth_no
	, auth_start
	, auth_expire
	, prev_auth_start
	, prev_auth_expire
	, CASE WHEN prev_auth_start IS NULL THEN auth_start
		WHEN DATEDIFF(d, auth_start, prev_auth_expire) <= 1 THEN prev_auth_start
		WHEN COALESCE(prev_enroll_days, 0) > COALESCE(enroll_days, 0) THEN prev_auth_start
		ELSE auth_start END AS longest_start
	, CASE WHEN prev_auth_expire IS NULL THEN auth_expire
		WHEN DATEDIFF(d, auth_start, prev_auth_expire) <= 1 THEN auth_expire
		WHEN COALESCE(prev_enroll_days, 0) > COALESCE(enroll_days, 0) THEN prev_auth_expire
		ELSE auth_expire END AS longest_expire
	FROM #cur_sums
),
temp_2 AS(
	SELECT *
	, CASE WHEN longest_start > @edate THEN NULL --Time started after SDA end
		WHEN @sdate > longest_expire THEN NULL --Time ended before SDA start
		WHEN longest_start >= @sdate THEN longest_start --Time started after SDA period
		WHEN longest_start < @sdate THEN @sdate --Time started before SDA period
		ELSE '1900-01-01' END AS longest_start2
	, CASE WHEN longest_start > @edate THEN NULL --Time started after SDA end
		WHEN @sdate > longest_expire THEN NULL --Time ended before SDA start
		WHEN longest_expire <= @edate THEN longest_expire --Time started after SDA period
		WHEN longest_expire > @edate THEN @edate --Time started before SDA period
		ELSE '1900-01-01' END AS longest_expire2
	FROM temp_1
)
UPDATE #cur_sums
SET calendar_month = CASE WHEN @mo1_start BETWEEN longest_start AND longest_expire
		AND @mo1_end BETWEEN longest_start AND longest_expire THEN 1
	WHEN @mo2_start BETWEEN longest_start AND longest_expire
		AND @mo2_end BETWEEN longest_start AND longest_expire THEN 1		
	WHEN @mo3_start BETWEEN longest_start AND longest_expire
		AND @mo3_end BETWEEN longest_start AND longest_expire THEN 1
	ELSE 0 END
FROM #cur_sums AS a 
LEFT JOIN temp_2 AS b ON a.kcid = b.kcid AND a.auth_no = b.auth_no

---------------------------------------------------------
--	Prepare data for SDA calculation
---------------------------------------------------------
--Now that all data are gathered, it's time to do the SDA calculation and output results.
--First, we will combine service hours delivered, service hours expected, and enrollment days across current and prior auths.
--Only auths active for a calendar month will be given an SDA calculation.
--The 'sda_link' program will handle exceptions to normal SDA processes (i.e. full-pay for new clients)

--Sum enrollment days, hours expected, and hours delivered
DROP TABLE IF EXISTS #sda_final;
SELECT kcid
, auth_no
, program
, age_group
, prev_auth_no
, calendar_month
, COALESCE(enroll_days, 0) + COALESCE(prev_enroll_days, 0) AS enroll_days --Enrollment days from both auths (if applicable)
, (COALESCE(svc_hrs_expected, 0) + COALESCE(prev_svc_hrs_expected, 0)) AS hrs_expected --Hours expected from both auths
, COALESCE(svc_hrs, 0) + COALESCE(prev_svc_hrs, 0) AS svc_hrs --Service hours delivered on both auths
INTO #sda_final
FROM #cur_sums

--Add a prorated service hours delivered metric and the SDA metric to the final table
ALTER TABLE #sda_final
ADD svc_hrs_prorated DEC(6,3)
, sda DEC(6,3);

--Calculated a pro-rated version of both service hours delivered and service hours expected
UPDATE #sda_final
SET svc_hrs_prorated = CASE WHEN enroll_days = 0 THEN NULL --No enrollment days
							ELSE 30.0*svc_hrs/enroll_days END, --Else, get pro-rated SVC hours
	hrs_expected = CASE WHEN enroll_days = 0 THEN NULL --No enrollment days
							ELSE 30.0*(hrs_expected/enroll_days) END --Otherwise

--Finally, SDA is the ratio of prorated hours delivered / prorated hours expected
UPDATE #sda_final
SET sda = CASE WHEN enroll_days < 28 THEN NULL --No SDA calculation: not enough enrollment
				WHEN calendar_month = 0 THEN NULL --Not enrolled for a full calendar month
				WHEN hrs_expected = 0 THEN NULL --No SDA calculation: no service hour expectation
				ELSE svc_hrs_prorated/hrs_expected END --Otherwise, calculate SDA

SELECT *
FROM #sda_final