SELECT b.kcid
, b.case_id AS agency_client_id
, a.auth_no
, au_stratum_id
, b.program AS cur_bene
, CASE WHEN b.program IN('2X1', '3A1', '3B1', '400', '401') AND d.[plan] = 'F19' THEN '400'
	WHEN b.program IN('2X1', '3A1', '3B1', '400', '401') AND d.[plan] = 'MID' THEN '401'
	ELSE 'MOP' END AS new_bene
, strat_level
, total_score
, age_group
, CASE WHEN language_differential = 'Y' THEN 0.1 ELSE 0 END AS language_differential
, CASE WHEN special_population = 'Y' THEN 0.1 ELSE 0 END AS special_population
, b.agency_id
, CASE WHEN b.start_date <= {mostart} THEN {mostart} ELSE b.start_date END AS mostart
, CASE WHEN ISNULL(b.expire_date, GETDATE()) >= {moend} THEN {moend}
    ELSE b.expire_date END AS moend
, missing_data
, c.sda
, sda_pay_multiplier
, CASE WHEN sda_rule = 'FPC' THEN 'Changed tiers (Full pay)'
	WHEN sda_rule = 'FPN' THEN 'New client (Full pay)'
	WHEN sda_rule = 'NOR' THEN 'Normal SDA rules'
	WHEN sda_rule = 'PQD' THEN 'Prior quarter SDA used (different auth. #)'
ELSE '' END AS sda_rule
, c.start_date AS sda_start
, c.end_date AS sda_end
, c.enroll_days
, c.hrs_expected
, c.svc_hrs
, c.svc_hrs_prorated
, CASE WHEN b.program IN('2X1', '3A1', '3B1', '400', '401') THEN 'M'
	WHEN b.program IN('S01', 'S02', '500', '501') THEN 'S'
	ELSE '' END AS case_mgr_type
, g_p1_client.p1_id
FROM au_stratum AS a
INNER JOIN au_master AS b ON a.auth_no = b.auth_no
LEFT JOIN au_stratum_sda AS c ON a.stratum_sda_id = c.stratum_sda_id
LEFT JOIN au_initial_plan AS d ON a.auth_no = d.auth_no
LEFT JOIN g_p1_client ON b.kcid = g_p1_client.kcid --Get Medicaid ID (if applicable)
WHERE a.start_date BETWEEN {qtr_start} AND {qtr_end}
    AND ISNULL(b.expire_date, {mostart}) >= {mostart}
    AND b.start_date <= {moend}
	AND b.status_code IN('AA', 'TM')

	