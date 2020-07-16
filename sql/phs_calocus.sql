/********************************************************************
*	phs_calocus.sql
*	By: Jon Downs
*	12/21/2019
*	Purpose: SQL query to generate CALOCUS scores
*********************************************************************/
/*UPDATES*/
--2019-01-14 (JD): The 'all agencies' piece was incorrectly looking at agency IDs.
--2020-03-05 (JD): Converting this to all be done in SQL
--2020-05-22 (JD): New program codes 400/401 implemented in the query. The other agency substitution no longer applies when CALOCUS is missing.
--2020-07-16 (JD): Modifying for Python conversion.

/*Declare query assessment date (will look for scores up to one month after this date)*/
SET NOCOUNT ON;
DECLARE @calcDate DATE;
SET @calcDate = :calc_date;

/*Initially, we will want to pull the CALOCUS score assigned by the agency, if it exists*/
DROP TABLE IF EXISTS #rsCALOCUSout
SELECT a.*, b.composite_score AS CALOC
INTO #rsCALOCUSout
FROM #phs_calocus_temp AS a LEFT JOIN
(
	SELECT kcid
	, agency_id
	, composite_score
	FROM 
	(
		SELECT kcid
		, agency_id
		, composite_score
		, ROW_NUMBER() OVER(PARTITION BY kcid, agency_id ORDER BY event_date DESC) AS rn
		FROM ep_CALOCUS
		WHERE event_date <= DATEADD(m, 3, @calcDate)
	) AS b
	WHERE rn = 1
) AS b ON a.kcid = b.kcid AND a.agency_id = b.agency_id

/*If missing, let's substitute a LOCUS score*/
UPDATE #rsCALOCUSout
SET CALOC = b.composite_score
FROM #rsCALOCUSout AS a
LEFT JOIN
(
	SELECT kcid
	, composite_score
	FROM 
	(
		SELECT kcid
		, composite_score
		, event_date
		, ROW_NUMBER() OVER(PARTITION BY kcid, agency_id ORDER BY event_date DESC) AS rn
		FROM ep_LOCUS
		WHERE event_date <= DATEADD(m, 3, @calcDate)
	) AS b
	WHERE rn = 1
) AS b ON a.kcid = b.kcid
WHERE a.CALOC IS NULL

/*Assign missing data flags*/
ALTER TABLE #rsCALOCUSout ADD CALOC_missDat CHAR(1);

UPDATE #rsCALOCUSout
SET CALOC_missDat = CASE WHEN program NOT IN('MHO', 'MOP', '400', '401') THEN 'N' --Not a mental health benefit: can't be missing
						WHEN age_group != 'C' THEN 'N' --Not a child: can't be missing
						WHEN CALOC IS NOT NULL THEN 'N' --Not missing
						ELSE 'Y' END --Required and missing
FROM #rsCALOCUSout

SELECT *
FROM #rsCALOCUSout