WITH conds AS(
	SELECT auth_no
	, CASE WHEN condition_code = '152' THEN 'caa_asthma' 
		WHEN condition_code = '153' THEN 'caa_diabetes'
		WHEN condition_code = '154' THEN 'caa_copd'
		WHEN condition_code = '155' THEN 'caa_cvd'
		ELSE 'caa_other' END AS condition_cat
	, 1 AS indicator
	FROM ma_cond_ass
)
SELECT a.auth_no
, a.p1_id
, ISNULL(caa_asthma, 0) AS caa_asthma
, ISNULL(caa_diabetes, 0) AS caa_diabetes
, ISNULL(caa_copd, 0) AS caa_copd
, ISNULL(caa_cvd, 0) AS caa_cvd
FROM #phs_chron_cond_temp AS a
LEFT JOIN (
	SELECT *
	FROM conds AS a
	PIVOT( MAX(indicator)
		FOR condition_cat IN([caa_asthma], [caa_diabetes], [caa_copd], [caa_cvd], [caa_other])
	) AS p
) AS b ON a.auth_no = b.auth_no
	