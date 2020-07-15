/********************************************************************
*	Identify clients to stratify									*
*	By: Jon Downs													*
*	12/21/2019														*
*	Purpose: SQL query to generate persons needing a PHS run		*
*********************************************************************/
/*UPDATES*/
/*1/22/2020 (JD)*/
--Pulled the case rate reason pieces into this query.
--Logic for adult/child benefit identification has changed. Geriatric 'G' now included as an age category.
--Variable names fixed to conform with new table design.

/*2/27/2020 (JD)*/
-- Changed the date pull for au_master to account for missing expiration dates. This will be necessary as of 4/1/2020.
-- Changed the code to pull Pending (PN) codes for authorizations. Will need further logic to remove these from the strat files.
-- Removing SUD auths for the time being. Will keep a lot of the code in anticipation of future re-implementation.

/* 3/3/2020 (JD)*/
-- Strat tables live in PHP96. Changing query to disregard auths that are already stratified in quarter (was happening in R).
-- Checks for complete data (not IP/PY for data status) and allowing 3 days after post date now added.

/* 3/13/2020 (JD)*/
-- Added function from Michael Csendes to pull case rate reasons using a function instead of AU_TIER

/* 5/22/2020 (JD)*/
-- Program codes converted to 400, 401, 500, 501 (still waiting on new SUD model, so some code is a 'placeholder')
-- Pulling in AU_INITIAL_TIER to determine payment plans. 
--		If missing, a generic 'MHO' or 'SUD' is used. 
--		This typically happens for pending auths. Plan is to add a daily 'checking' script that cleans up pending auths that now have payment plans.
-- Now checking if this auth is a continuation of benefits (COB) from a previous auth at the same agency. This has payment/tiering implications.
--			There's some redundant coding in order to improve script runtimes.

/*Declare Query Start and End Dates*/
DECLARE @qStart DATE, @qEnd DATE, @calc_date DATE, @last_qtr_date DATE;
SET @qStart = ?; --First day, current quarter
SET @qEnd = ?; --Last day, current quarter
SET @calc_date = GETDATE(); --Calculation date (today)
SET @last_qtr_date = DATEADD(qq, -1, @qStart); --First day of prior quarter

/*Identify auths that need stratification*/
WITH auths AS(
	SELECT a.kcid
	, a.auth_no
	, @qStart AS phs_start_date
	, @qEnd AS phs_end_date
	, @calc_date AS calc_date
	, agency_id
	, start_date
	, expire_date
	, CASE WHEN program IN('400', '401', '500', '501') THEN program --Already correct
		WHEN program IN('2X1', '3A1', '3B1', 'MOP', 'MOM') AND d.[plan] = 'F19' THEN '400' --MH, Medicaid payer
		WHEN program IN('2X1', '3A1', '3B1', 'MOP', 'MOM') AND d.[plan] = 'MID' THEN '401' --MH, MIDD payer
		WHEN program IN('2X1', '3A1', '3B1', 'MOP', 'MOM') THEN 'MOP' --MH, unknown/other funding
		WHEN program IN('S01', 'S02', 'SOP', 'SOM') AND d.[plan] = 'F19' THEN '500' --SUD, Medicaid payer
		WHEN program IN('S01', 'S02', 'SOP', 'SOM') AND d.[plan] = 'MID' THEN '501' --SUD, MIDD payer
		WHEN program IN('S01', 'S02', 'SOP', 'SOM') THEN 'SOP' --SUD, unknown/other funding
		ELSE '' END AS program
	, program AS current_program
	, CASE WHEN program IN('2X1', '3A1', '3B1', 'MOP', 'MOM', '400', '401') THEN 'MH'
		WHEN program IN('S01', 'S02', 'SOP', 'SOM', '500', '501') THEN 'SUD'
		ELSE '' END AS tx_focus
	, crv.age_group
	, crv.special_population
	, crv.language_differential
	, (CONVERT(INT,CONVERT(CHAR(8), @qstart, 112))-CONVERT(CHAR(8), c.dob, 112))/10000 AS age
	FROM au_master AS a
	LEFT JOIN g_person AS c ON a.kcid = c.kcid
	LEFT JOIN au_initial_plan AS d ON a.auth_no = d.auth_no
	CROSS APPLY kcrsn.[p_get_case_rate_elements](a.kcid, a.auth_no, @calc_date) as crv
	WHERE program IN('3A1', '3B1', '2X1', '400', '401', 'S01', 'S02', '500', '501') --MH programs
		AND status_code IN('AA', 'TM', 'PN') --Active/terminated/pending
		AND
		(
			a.start_date BETWEEN @qStart AND @qEnd 
			OR a.expire_date BETWEEN @qStart AND @qEnd
			OR (a.start_date <= @qEnd AND a.expire_date >= @qStart)
			OR (a.expire_date IS NULL AND a.start_date BETWEEN @qStart AND @qEnd)
		) /*In the specified date range*/
		AND a.auth_no NOT IN(SELECT auth_no FROM au_stratum	WHERE calc_date BETWEEN @qstart AND @qEnd) --Not already stratified
		AND (
				CAST(a.post_stamp AS DATE) <= CAST(DATEADD(d, -3, GETDATE()) AS DATE) --In system 3+ days ago (to allow for risk data to be gathered)
				OR (@qStart = '2020-07-01' AND program IN('400', '401') AND a.post_stamp < '2020-07-01') --Special case for initial conversion
			)
		AND a.data_status != 'ID' --Sufficient data for PHS model
)
/*Final output*/
SELECT a.*
, g_p1_client.p1_id
FROM auths AS a --Authorization info and pay status
LEFT JOIN g_p1_client ON a.kcid = g_p1_client.kcid --Get Medicaid ID (if applicable)