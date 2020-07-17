/********************************************************************
*	phs_foster.sql
*	By: Jon Downs
*	12/21/2019
*	Purpose: SQL query to generate foster history
*********************************************************************/
/*UPDATES*/
--2/28/2020 (JD): Changing variable name to FOSTR.

/*Declare the assessment date*/
DECLARE @edate DATE;
SET @edate = :calc_date;

/*Get all kids with history of foster care*/
/*Residential code indicative of foster care*/
WITH fostHome AS(

	SELECT DISTINCT kcid , 1 AS FOSTR
	FROM ep_residence
	WHERE resid_arrng_code IN('26', '46', '47')
),
/*Medicaid benefit indicative of foster care*/
fostCov AS(
	SELECT DISTINCT kcid, 1 AS FOSTR
  	FROM ep_coverage_mco
  	WHERE plan_type = 'FOSTR'
		AND start_date <= DATEADD(m, 1, @edate)
  	GROUP BY kcid
)
SELECT DISTINCT a.*, ISNULL(FOSTR, 0) AS FOSTR
FROM #phs_foster_temp AS a LEFT JOIN
(
	SELECT *
	FROM fostHome

	UNION ALL 

	SELECT *
	FROM fostCov
) AS b ON a.kcid = b.kcid