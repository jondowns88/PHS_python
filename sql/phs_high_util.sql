/********************************************************************
*	phs_high_util.sql
*	By: Jon Downs
*	12/21/2019
*	Purpose: SQL query to generate Involuntary Tx, SUD residential,
*			and SUD withdrawal events from PHP96
*********************************************************************/

/*Declare assessment start/end dates*/
DECLARE @calc_date DATE, @lb_date DATE;
SET @calc_date = :calc_date;
SET @lb_date = DATEADD(m, -12, @calc_date);

/*Get total number of ITA/SRS/DTX events during the lookback period*/
WITH high_util_auths AS(
	SELECT k.kcid,
	SUM(CASE WHEN program = 'SRS' THEN 1 ELSE 0 END) AS nSRS,
	SUM(CASE WHEN program = 'DTX' THEN 1 ELSE 0 END) AS nDTX,
	SUM(CASE WHEN program = 'IP' THEN 1 ELSE 0 END) AS nITA
	FROM jdowns.phs_hutil_temp AS k
	INNER JOIN bhrd.au_master AS a ON k.kcid = a.kcid
	LEFT JOIN
	(
		SELECT DISTINCT auth_no, ip_type
		FROM bhrd.ip_master
	) AS b ON a.auth_no = b.auth_no
	WHERE
	(
		program IN('SRS', 'DTX')
		OR (program = 'IP' AND ip_type = 'I')
	)
		AND status_code IN('AA', 'TM')
		AND (
			start_date BETWEEN @lb_date AND @calc_date
			OR expire_date BETWEEN @lb_date AND @calc_date
			)
	GROUP BY k.kcid
),
ed_ip AS(
	SELECT kcid
	, SUM(CASE WHEN major_class = 'Emergency' THEN 1 ELSE 0 END) AS nED
    , SUM(CASE WHEN major_class = 'Inpatient' THEN 1 ELSE 0 END) AS nIP
    FROM bhrd.cmt_hospital_report
	WHERE admit_date BETWEEN @lb_date AND @calc_date
    GROUP BY kcid
)
SELECT *
, nSRS + nDTX + nITA + nED + nIP AS HUTIL
FROM
(
	SELECT ISNULL(a.kcid, b.kcid) AS kcid
	, ISNULL(nSRS, 0) AS nSRS
	, ISNULL(nDTX, 0) AS nDTX
	, ISNULL(nITA, 0) AS nITA
	, ISNULL(nED, 0) AS nED
	, ISNULL(nIP, 0) AS nIP
	FROM high_util_auths AS a
	FULL JOIN ed_ip AS b ON a.kcid = b.kcid
) AS a