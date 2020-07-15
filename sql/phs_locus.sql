/********************************************************************
*	phs_locus.sql
*	By: Jon Downs
*	12/21/2019
*	Purpose: SQL query to generate LOCUS scores
*********************************************************************/
/*UPDATES*/
--2019-01-14: The 'all agencies' piece was incorrectly looking at agency IDs.
--2020-03-05: Converting this to all be done in SQL
--2020-05-22: Converting to new program codes in missing flag logic. Other agency substitution for missing scores no longer applies.

/*Declare query assessment date (will look for scores up to one month after this date)*/
DECLARE @calcDate DATE;
SET @calcDate = {calc_date};

/*Initially, we will want to pull the LOCUS score assigned by the agency, if it exists*/
DROP TABLE IF EXISTS ##rsLOCUSout
SELECT a.*
, b.composite_score AS LOCUS
INTO {`temp_tab_out`}
FROM {`temp_tab_in`} AS a LEFT JOIN
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
		FROM ep_LOCUS
		WHERE event_date <= DATEADD(m, 3, @calcDate)
	) AS b
	WHERE rn = 1
) AS b ON a.kcid = b.kcid AND a.agency_id = b.agency_id

/*If none of that works, let's substitute a CALOCUS score*/
UPDATE {`temp_tab_out`}
SET LOCUS = b.composite_score
FROM {`temp_tab_out`} AS a
LEFT JOIN
(
	SELECT kcid, composite_score
	FROM 
	(
		SELECT kcid, composite_score, event_date, ROW_NUMBER() OVER(PARTITION BY kcid, agency_id ORDER BY event_date DESC) AS rn
		FROM ep_LOCUS
		WHERE event_date <= DATEADD(m, 3, @calcDate)
	) AS b
	WHERE rn = 1
) AS b ON a.kcid = b.kcid
WHERE a.LOCUS IS NULL

/*Assign missing data flags*/
ALTER TABLE {`temp_tab_out`} ADD LOCUS_missDat CHAR(1);

UPDATE {`temp_tab_out`}
SET LOCUS_missDat = CASE WHEN program NOT IN('MHO', 'MOP', '400', '401') THEN 'N' --Not a mental health benefit: not required
						WHEN age_group NOT IN('A', 'G') THEN 'N' --Not an adult: not required
						WHEN LOCUS IS NOT NULL THEN 'N' --Not missing
						ELSE 'Y' END --Required and missing
FROM {`temp_tab_out`}