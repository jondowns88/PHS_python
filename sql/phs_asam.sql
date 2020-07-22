/********************************************************************
*	rsASAMqry.sql													*
*	By: Jon Downs													*
*	12/21/2019														*
*	Purpose: SQL query to generate ASAM scores						*
*********************************************************************/
/*UPDATES*/
--1/14/2020: The any agency code was still matching on agency ID's.
--7/6/2020: Adding procedure from Michael C.

/*Declare query assessment date (will look for scores up to one month after this date)*/
DECLARE @calc_date DATE;
SET @calc_date = :calc_date;

--Use the ASAM determination tool
WITH asam1 AS(
	SELECT a.kcid
	, a.agency_id
	, b.event_date AS asam_date
	, b.event_type AS asam_type
	, b.level AS asam_loc_request
	, kcrsn.[p_get_asam_level_indicated] (a.kcid, b.event_date, b.event_type) AS asam_loc	
	FROM #phs_asam AS a 
	INNER JOIN ep_asam_placement AS b ON a.kcid = b.kcid AND a.agency_id = b.agency_id
	WHERE b.event_date BETWEEN CAST(DATEADD(m, -24, @calc_date) AS DATE) AND CAST(DATEADD(m, 3, @calc_date) AS DATE)
		AND event_type = 'OP'
),
--Pull the most recent ASAM whose level is indicative of outpatient care
asam2 AS(
	SELECT *
	FROM
	(
		SELECT *
		, ROW_NUMBER() OVER(PARTITION BY kcid, agency_id ORDER BY asam_date DESC) AS rn
		FROM asam1
	) AS a
	WHERE rn = 1
)
--Final product
SELECT a.*
, CAST(TRIM(REPLACE(REPLACE(b.asam_loc, '-WM', ''), 'OTP', '5')) AS DEC(4,1)) AS ASAM
, 'N' AS ASAM_missing_data
FROM #phs_asam AS a
LEFT JOIN asam2 AS b ON a.kcid = b.kcid
	AND a.agency_id = b.agency_id