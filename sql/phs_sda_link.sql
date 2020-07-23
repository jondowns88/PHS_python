/*******************************************************************
*	sda_link.sql												
*	By: Jon Downs													
*	6/1/2020														
*	Purpose: Three main goals:
*				1) Link stratification data to the appropriate SDA calculation
*				2) Determine which stratifications are exceptions to normal SDA processes
*				3) Determine SDA payment multipliers based on (1) and (2)
*********************************************************************/
--UPDATES
-- 6/1/2020 (JD): Initialized the program.
-- 6/3/2020 (JD): Added comments and explanations for presentation at ISAC

/*
	Note: In production, this code is called in R. Users will need to replace {`temp_tab_in`} with
			a temporary table that contains a list au_stratum_id's for the clients who need to be linked.
*/
--------------------------------------------------------------------------
--	Initialize data for clients who need SDA payment multiplier determination
--------------------------------------------------------------------------
DROP TABLE IF EXISTS #temp_1;
SELECT a.kcid
, a.auth_no
, a.agency_id
, a.start_date
, a.expire_date
, CASE WHEN a.program IN('2X1', '3A1', '3B1', '400', '401') THEN 'MH'
	WHEN a.program IN('S01', 'S02', '500', '501') THEN 'SUD'
	ELSE '' END AS tx_focus
, b.au_stratum_id
, b.start_date AS phs_start_date
, b.end_date AS phs_end_date
, b.age_group
, b.strat_level
, b.sda_rule
INTO #temp_1
FROM kcrsn.au_master AS a--Auths database
INNER JOIN kcrsn.au_stratum AS b ON a.auth_no = b.auth_no --Same auth
	AND b.au_stratum_id IN(SELECT au_stratum_id FROM {`temp_tab_in`}) --User-defined list of clients needing SDA payment multiplier determination
	AND b.start_date >= '2020-01-01' --Not in September 2019 (SDA first ran in 1/2020)
WHERE program IN('2X1', '3A1', '3B1', 'S01', 'S02', '400', '401', '500', '501') --Tiered MH/SUD program
	AND status_code IN('AA', 'TM', 'PN') --Active/terminated/pending

--------------------------------------------------------------------------
--	Get ID # for the current quarter's stratification (may be overridden)
--------------------------------------------------------------------------
--Unless an exception applies, we will use the SDA calculation that ended one month before the quarter began.
--So, let's pull those. We may choose to override it later, based on exception rules.
ALTER TABLE #temp_1
ADD stratum_sda_id INT --SDA ID for the current quarter
, enroll_days INT; --Days enrolled

UPDATE #temp_1
SET stratum_sda_id = b.stratum_sda_id
, enroll_days = b.enroll_days
FROM #temp_1 AS a
LEFT JOIN kcrsn.au_stratum_sda AS b ON a.auth_no = b.auth_no
	AND a.phs_start_date = DATEADD(m, 1, DATEADD(d, 1, b.end_date)) --SDA period ending 1 month before the quarter began

--------------------------------------------------------------------------
--	Get first stratification for this authorization
--------------------------------------------------------------------------
--For benefits that are continuations of a prior authorization, a full-pay exception will be applied if the final tier of the prior benefit is different from either of the
	--first two quarters of the new benefit.
ALTER TABLE #temp_1
ADD first_strat CHAR(1) --First stratification for this auth (need to make sure tier change exception for new benefits does not apply)
, strat_check_end DATE; --Last day that a tier change exception could apply for a new stratification 

UPDATE #temp_1
SET first_strat = b.strat_level
, strat_check_end = b.strat_check_end
FROM #temp_1 AS a
LEFT JOIN
(
	SELECT a.auth_no
	, a.strat_level
	, CASE WHEN a.start_date = '2019-09-01' THEN '2020-01-01' --September 2019 SDA is a special case
		ELSE DATEADD(q, 1, a.start_date) END AS strat_check_end
	FROM kcrsn.au_stratum AS a
	INNER JOIN --Find first tier for this auth.
	(
		SELECT auth_no
		, MIN(start_date) AS start_date
		FROM kcrsn.au_stratum
		GROUP BY auth_no
	) AS b ON a.auth_no = b.auth_no AND a.start_date = b.start_date
) AS b ON a.auth_no = b.auth_no;

--------------------------------------------------------------------------
--	Get last stratification for this authorization
--------------------------------------------------------------------------
--If the LOC changed from one quarter to the next, an exception requires that client to be paid at 100% for the quarter in which the tier changed.
ALTER TABLE #temp_1
ADD last_strat CHAR(1)
, last_stratum_sda_id INT;

UPDATE #temp_1
SET last_strat = b.strat_level
, last_stratum_sda_id = b.stratum_sda_id
FROM #temp_1 AS a
LEFT JOIN
(
	SELECT a.auth_no
	, a.strat_level
	, a.stratum_sda_id
	FROM kcrsn.au_stratum AS a
	INNER JOIN --Find date of most recent tiering
	(
		SELECT auth_no
		, MAX(start_date) AS start_date
		FROM kcrsn.au_stratum
		WHERE au_stratum_id NOT IN(SELECT au_stratum_id FROM #temp_1)
		GROUP BY auth_no
	) AS b ON a.auth_no = b.auth_no AND a.start_date = b.start_date
) AS b ON a.auth_no = b.auth_no;

--------------------------------------------------------------------------
--	Check for prior benefits ending within the past 90 days
--------------------------------------------------------------------------
ALTER TABLE #temp_1
ADD prev_auth_no INT --Authorization number prior to current (ended within 90 days)
, prev_auth_end DATE; --Day the prior auth no expired

UPDATE #temp_1
SET prev_auth_no = b.auth_no
, prev_auth_end = b.expire_date
FROM #temp_1 AS a
LEFT JOIN(
	SELECT kcid
	, auth_no
	, expire_date
	, agency_id
	, CASE WHEN program IN('2X1', '3A1', '3B1', '400', '401') THEN 'MH'
		WHEN program IN('S01', 'S02', '500', '501') THEN 'SUD'
		ELSE '' END AS tx_focus
	FROM kcrsn.au_master
	WHERE program IN('2X1', '3A1', '3B1', '400', '401', 'S01', 'S02', '500', '501')
		AND status_code IN('AA', 'TM')
		AND kcid IN(SELECT DISTINCT kcid FROM #temp_1)
) AS b ON a.kcid = b.kcid --Same client
	AND a.agency_id = b.agency_id --Same agency
	AND a.tx_focus = b.tx_focus --Same TX focus
	AND a.auth_no != b.auth_no --Different auths
	AND DATEDIFF(d, b.expire_date, a.start_date) BETWEEN 0 AND 90; --Auth to join ended within 90 days of new auth
	
--------------------------------------------------------------------------
--	Get last SDA from prior authorization (may be used to determine a full-pay exception)
--------------------------------------------------------------------------
ALTER TABLE #temp_1
ADD pqd_strat CHAR(1) --Last strat from prior auth
, pqd_sda_id INT; --ID for last SDA calculation for prior auth

UPDATE #temp_1
SET pqd_strat = b.strat_level
, pqd_sda_id = b.stratum_sda_id
FROM #temp_1 AS a
LEFT JOIN
(
	SELECT a.auth_no
	, a.strat_level
	, a.stratum_sda_id
	FROM kcrsn.au_stratum AS a
	INNER JOIN --Find date of most recent tiering
	(
		SELECT auth_no
		, MAX(start_date) AS start_date
		FROM kcrsn.au_stratum
		GROUP BY auth_no
	) AS b ON a.auth_no = b.auth_no AND a.start_date = b.start_date
) AS b ON a.prev_auth_no = b.auth_no;

--------------------------------------------------------------------------
--	Determine SDA rule, link to SDA data
--------------------------------------------------------------------------
ALTER TABLE #temp_1
ADD new_sda_rule CHAR(3)
, new_stratum_sda_id INT;

UPDATE #temp_1
SET new_sda_rule = 
		CASE WHEN first_strat != ISNULL(pqd_strat, first_strat) AND phs_start_date <= strat_check_end THEN 'FPC' --New auth began with LOC change: pay 100% for up to 2 qtr
			WHEN ISNULL(last_strat, strat_level) != strat_level THEN 'FPC' --LOC change from prior quarter: pay 100%
			WHEN enroll_days >= 31 THEN 'NOR' --SDA can be calculated using normal rules
			WHEN pqd_sda_id IS NOT NULL THEN 'PQD' --SDA cannot be calculated this quarter: use info from prior authorization
			ELSE 'FPN' END, --SDA cannot be calculated, no look-back available: full pay, new client
	new_stratum_sda_id =
		CASE WHEN first_strat != ISNULL(pqd_strat, first_strat) AND phs_start_date <= strat_check_end THEN stratum_sda_id --New auth began with LOC change: link to current SDA
			WHEN ISNULL(last_strat, strat_level) != strat_level THEN stratum_sda_id --LOC change from prior quarter: link to current SDA
			WHEN enroll_days >= 31 THEN stratum_sda_id --SDA can be calculated using normal rules: link to current SDA
			WHEN pqd_sda_id IS NOT NULL THEN pqd_sda_id --SDA cannot be calculated this quarter: link to most recent SDA from prior authorization
			ELSE stratum_sda_id END --New client, receives 100% payment for first quarter: link to current SDA
FROM #temp_1

--------------------------------------------------------------------------
--	Determine SDA payment multiplier
--------------------------------------------------------------------------
ALTER TABLE #temp_1
ADD new_sda DEC(6, 3)
, new_sda_pay_multiplier DEC(6,3);

UPDATE #temp_1
SET new_sda = b.sda
, new_sda_pay_multiplier =
	CASE WHEN a.new_sda_rule IN('FPC', 'FPN', 'SHA') THEN 1.00
		ELSE ISNULL(c.sda_pay_multiplier, 1.00) END
FROM #temp_1 AS a
LEFT JOIN kcrsn.au_stratum_sda AS b ON a.new_stratum_sda_id = b.stratum_sda_id
LEFT JOIN (
	SELECT *,
	CASE WHEN program IN('MOP', '2X1', '3A1', '3B1', '400', '401') THEN 'MH'
		WHEN program IN('SOP', 'S01', 'S02', '500', '501') THEN 'SUD'
		ELSE '' END AS tx_focus
	FROM kcrsn.cd_stratum_pay_corridor
) AS c ON a.tx_focus = c.tx_focus
	AND a.age_group = c.age_group
	AND b.sda BETWEEN c.sda_low AND c.sda_high

--------------------------------------------------------------------------
--	Update production table with linked SDA, SDA payment multiplier, and SDA rule
--------------------------------------------------------------------------
UPDATE au_stratum
SET sda_rule = b.new_sda_rule
, sda_pay_multiplier = b.new_sda_pay_multiplier
, stratum_sda_id = b.new_stratum_sda_id
, modify_stamp = CURRENT_TIMESTAMP
FROM kcrsn.au_stratum AS a
INNER JOIN #temp_1 AS b ON a.au_stratum_id = b.au_stratum_id