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
SET @calc_date = {calc_date};

--Use the ASAM determination tool
WITH asam1 AS(
	SELECT a.kcid
	, a.agency_id
	, b.event_date AS asam_date
	, b.event_type AS asam_type
	, b.level AS asam_loc_request
	, kcrsn.[p_get_asam_level_indicated] (a.kcid, b.event_date, b.event_type) AS asam_loc	
	FROM {`temp_tab_in`} AS a 
	INNER JOIN ep_asam_placement AS b ON a.kcid = b.kcid
	WHERE b.event_date BETWEEN CAST(DATEADD(m, -24, @calc_date) AS DATE) AND CAST(DATEADD(m, 3, @calc_date) AS DATE)
		AND event_type = 'OP'
),
--Pull the most recent ASAM whose level is indicative of outpatient care
asam2 AS(
	SELECT *
	FROM
	(
		SELECT *
		, ROW_NUMBER() OVER(PARTITION BY kcid ORDER BY asam_date DESC) AS rn
		FROM asam1
		WHERE asam_loc NOT IN('2.5', '3.1', '3.2-WM', '3.3', '3.5', '3.7-WM', '3.7', '4-WM', '4', 'OTP')
	) AS a
	WHERE rn = 1
)
--Final product
SELECT a.*
, b.asam_date
, b.asam_type
, b.asam_loc_request
, b.asam_loc
FROM {`temp_tab_in`} AS a
LEFT JOIN asam2 AS b ON a.kcid = b.kcid