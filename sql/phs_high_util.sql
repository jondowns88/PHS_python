/********************************************************************
*	phs_high_util.sql
*	By: Jon Downs
*	12/21/2019
*	Purpose: SQL query to generate Involuntary Tx, SUD residential,
*			and SUD withdrawal events from PHP96
*********************************************************************/

/*Declare assessment start/end dates*/
DECLARE @calcDate DATE, @lbDate DATE;
SET @calcDate = {calc_date};
SET @lbDate = {lb_date};

/*Get total number of ITA/SRS/DTX events during the lookback period*/
SELECT k.kcid,
SUM(CASE WHEN program = 'SRS' THEN 1 ELSE 0 END) AS nSRS,
SUM(CASE WHEN program = 'DTX' THEN 1 ELSE 0 END) AS nDTX,
SUM(CASE WHEN program = 'IP' THEN 1 ELSE 0 END) AS nITA
FROM {`temp_tab_in`} AS k
INNER JOIN au_master AS a ON k.kcid = a.kcid
LEFT JOIN
(
	SELECT DISTINCT auth_no, ip_type
	FROM ip_master
) AS b ON a.auth_no = b.auth_no
WHERE
(
	program IN('SRS', 'DTX')
	OR (program = 'IP' AND ip_type = 'I')
)
	AND status_code IN('AA', 'TM')
	AND (
		start_date BETWEEN @lbDate AND @calcDate
		OR expire_date BETWEEN @lbDate AND @calcDate
		)
GROUP BY k.kcid
