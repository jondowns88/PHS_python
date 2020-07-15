USE php96;

--Add columns for previous authorization numbers
ALTER TABLE ##rsTotalScoreTMP
ADD first_strat_qstart DATE
, first_strat CHAR(1)
, prev_auth_no INT
, prev_auth_expire DATE;

UPDATE ##rsTotalScoreTMP
SET first_strat_qstart =  CASE WHEN DATEADD(qq, DATEDIFF(qq, 0, start_date), 0) = '2019-10-01' THEN '2019-09-01'
, prev_auth_no = b.prev_auth_no
, prev_auth_expire = b.prev_auth_expire
FROM ##rsTotalScoreTMP AS a
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
	FROM au_master
	WHERE status_code IN('AA', 'TM')
		AND kcid IN(SELECT kcid FROM ##rsTotalScoreTMP) --To speed things up, only take KCIDs in our list
) AS b
ON a.kcid = b.kcid --Same client
	AND a.agency_id = b.agency_id --Same agency
	AND a.tx_focus = b.tx_focus --Same TX focus
	AND a.auth_no != b.prev_auth_no --Different auth no
	AND DATEDIFF(d, b.prev_auth_expire, a.start_date) BETWEEN 0 AND 90 --Prior auth ended within 90 days of new auth

UPDATE ##rsTotalScoreTMP
SET first_strat = b.strat_level
FROM ##rsTotalScoreTMP AS a
INNER JOIN au_stratum AS b ON a.auth_no = b.auth_no
	AND a.first_strat_qstart = b.start_date;

ALTER TABLE ##rsTotalScoreTMP
ADD prev_auth_last_strat CHAR(1);
, prev_auth_expire DATE;
SELECT a.auth_no
, a.program
, a.age_group
, a.calc_date
, a.total_score
, a.missDat
, b.strat_level
, b.svc_hrs_req
FROM ##rsTotalScoreTMP AS a
LEFT JOIN cd_stratum_tier AS b ON a.program = b.program
	AND a.age_group = b.age_group
	AND a.total_score BETWEEN range_low AND range_high
	AND calc_date BETWEEN start_date AND end_date