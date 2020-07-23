/********************************************************************
*	phs_homeless.sql
*	By: Jon Downs
*	12/21/2019
*	Purpose: SQL query to generate homeless history for benefits
*********************************************************************/
/*Declare the assessment date*/
DECLARE @edate DATE;
SET @edate = :calc_date;

SELECT k.*, 1 AS HMLES
FROM #phs_homeless_temp AS k
INNER JOIN kcrsn.ep_residence AS a ON a.kcid = k.kcid
INNER JOIN
(
	SELECT kcid, MAX(start_date) AS start_date
	FROM kcrsn.ep_residence
	WHERE start_date <= DATEADD(m, 1, @edate)
	GROUP BY kcid
) AS b ON a.kcid = b.kcid AND a.start_date = b.start_date
	AND resid_arrng_code = '82'