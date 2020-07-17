/*******************************************************************
*	phs_cj.sql
*	By: Jon Downs
*	7/17/2020
*	Purpose: Get criminal justice events
*********************************************************************/
--Define date variables
SET NOCOUNT ON;
DECLARE @calc_date DATE = :calc_date;
DECLARE @lb_six_months DATE = DATEADD(m, -6, @calc_date);
DECLARE @lb_five_years DATE = DATEADD(m, -60, @calc_date);

--Get all distinct CJ events
DROP TABLE IF EXISTS #all_cj;
WITH ep AS(
	SELECT kcid
	, book_date
	, ISNULL(release_date, book_date) AS release_date
	FROM ep_jail
	WHERE (
			book_date BETWEEN @lb_five_years AND @calc_date
			OR ISNULL(release_date, book_date) BETWEEN @lb_five_years AND @calc_date
			OR (book_date <= @calc_date AND ISNULL(release_date, book_date) >= @lb_five_years)
		 )
),
muni AS(
	SELECT kcid_match AS kcid
	, booking_start AS book_date
	, ISNULL(booking_end, booking_start) AS release_date
	FROM muni_jail
	WHERE kcid_match IS NOT NULL 
	AND
		(
			booking_start BETWEEN @lb_five_years AND @calc_date
			OR ISNULL(booking_end, booking_start) BETWEEN @lb_five_years AND @calc_date
			OR (booking_start <= @calc_date AND ISNULL(booking_end, booking_start) >= @lb_five_years)
		 )

),
all_cj AS(
	SELECT DISTINCT *
	FROM
	(
		SELECT *
		FROM ep
		UNION ALL
		SELECT *
		FROM muni
	) AS a
)
--Find events with overlapping dates, take the max/min of all overlaps
SELECT kcid
, book_date
, release_date
, SUM(new_event) OVER(PARTITION BY kcid ORDER BY book_date, release_date) AS grp
INTO #all_cj
FROM
(
	SELECT *
	, CASE WHEN LAG(release_date) OVER(PARTITION BY kcid ORDER BY book_date, release_date) IS NULL THEN 1
		WHEN book_date <= LAG(release_date) OVER(PARTITION BY kcid ORDER BY book_date, release_date) THEN 0 
		ELSE 1 END AS new_event
	FROM all_cj
) AS a

--Deduplicate between systems
DROP TABLE IF EXISTS #all_cj_dedup;
SELECT kcid
, grp
, MIN(book_date) AS book_date
, MAX(release_date) AS release_date
INTO #all_cj_dedup
FROM #all_cj
GROUP BY kcid, grp

--Sum of jail events in past 6 months and any jail events >2 years, (ending within past 5)
SELECT kcid
, SUM(CASE WHEN release_date >= @lb_six_months THEN 1 ELSE 0 END) AS NUMCJ
, MAX(CASE WHEN DATEDIFF(yy, book_date, release_date) >= 2 THEN 1 ELSE 0 END) AS LNGCJ
FROM #all_cj_dedup
GROUP BY kcid
ORDER BY LNGCJ DESC

