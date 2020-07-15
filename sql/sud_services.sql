SET NOCOUNT ON; --Helps with running queries in R.
---------------------------------------------------------
--	Set Parameters
---------------------------------------------------------
/*Declare report dates*/
DECLARE @sdate DATE, @edate DATE;
SET @sdate = {start_date}; /*SDA calculation start date*/
SET @edate = {end_date}; /*SDA calculation end date*/

SELECT a.auth_no
, ISNULL(b.svc_hrs, 0) AS svc_hrs
FROM {`temp_tab_in`} AS a
LEFT JOIN (
	SELECT auth_no
	, SUM(CASE WHEN service_minutes < 0 THEN 0 ELSE service_minutes/60.0 END) AS svc_hrs
	FROM ea_cpt_service 
	WHERE auth_no IN(SELECT auth_no FROM {`temp_tab_in`})
		AND source_id NOT IN(3,6,7,8)
		AND event_date BETWEEN @sdate AND @edate 
		AND service_minutes > 0 --Don't include negative service minutes
	GROUP BY auth_no
) AS b ON a.auth_no = b.auth_no
