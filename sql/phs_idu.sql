/********************************************************************
*	phs_idu.sql
*	By: Jon Downs
*	12/21/2019
*	Purpose: SQL query to generate IDU history for SUD benefits
*********************************************************************/
/*Declare the assessment date*/
DECLARE @edate DATE;
SET @edate = {calc_date};

SELECT DISTINCT k.*, 1 AS IDU
FROM {`temp_tab_in`} AS k
INNER JOIN ep_substance_use AS a ON k.kcid = a.kcid
INNER JOIN
(
	/*Most recent date IDU was reported*/
	SELECT kcid, MAX(event_date) AS event_date
	FROM ep_substance_use
	WHERE method = 2
		AND event_date <= DATEADD(m, 1, @edate) /*Reported on or before 1 month after assessment date*/
	GROUP BY kcid
) AS mr ON a.kcid = mr.kcid AND a.event_date = mr.event_date
WHERE a.event_date BETWEEN
		DATEADD(d, -365, @edate) AND /*One year before the assessment date*/
		DATEADD(m, 1, @edate) /*One month after the assessment date*/
	AND method = 2 /*Injection as method of drug use (regardless of substance)*/