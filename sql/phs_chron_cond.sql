/********************************************************************
*	phs_chron_cond.sql
*	By: Jon Downs
*	12/21/2019
*	Purpose: SQL query to generate homeless history for benefits
			Note: This is a PHClaims query, not PHP96
*********************************************************************/
/*Declare the assessment date*/
DECLARE @edate DATE, @lbdate DATE;
SET @edate = {calc_date};
SET @lbdate = DATEADD(yy, -2, @edate); /*I'm arbitrarily choosing two years as the look-back period*/

/*Get flags for each chronic condition, return max for each.*/
WITH CTE AS
(
	SELECT kcid
	, auth_no
	, [id_mcaid]
	, [ccw_desc], 1 AS [flag]
	FROM {`temp_tab_in`} AS a
	LEFT JOIN [final].[mcaid_claim_ccw] AS b ON a.p1_id = b.id_mcaid
	WHERE 1 = 1
		AND [ccw_desc] IN ('ccw_diabetes', 'ccw_ischemic_heart_dis', 'ccw_mi',
			'ccw_hypertension', 'ccw_stroke', 'ccw_hyperlipid',	'ccw_heart_failure',
			'ccw_atrial_fib', 'ccw_asthma','ccw_copd')
		AND ([from_date] <= @edate)
),
FLAG AS(	
	SELECT DISTINCT a.p1_id
	, a.kcid
	, a.auth_no
	, CASE WHEN COALESCE(elig, 0) = 0 THEN 'Y' /*No eligibility in lookback period*/
  		WHEN COALESCE(claim, 0) = 0 THEN 'Y' /*No claims in lookback period*/
  		WHEN a.p1_id IS NULL THEN 'Y' /*No Medicaid ID, cannot have claims*/
  		ELSE 'N' END AS CHRON_missDat /*Medicaid information found*/
	FROM {`temp_tab_in`} AS a
	LEFT JOIN
	(
  		SELECT id_mcaid, 1 AS elig
  		FROM final.mcaid_elig_timevar
  		WHERE [from_date] <= @edate AND [to_date] >= @lbdate
  			OR [from_date] BETWEEN @lbdate AND @edate
  			OR [to_date] BETWEEN @lbdate AND @edate
  		GROUP BY id_mcaid
	  ) AS b ON a.p1_id = b.id_mcaid
	  LEFT JOIN
	  (
  		SELECT id_mcaid, 1 AS claim
  		FROM final.mcaid_claim_header
  		WHERE first_service_date BETWEEN @lbdate AND @edate
  		GROUP BY id_mcaid
	  ) AS d ON a.p1_id = d.id_mcaid

)
SELECT DISTINCT c.kcid
, c.auth_no
, c.p1_id,
ISNULL(ccw_diabetes, 0) AS [ccw_diabetes],
CASE WHEN ISNULL(ccw_ischemic_heart_dis, 0) = 1
	OR ISNULL(ccw_mi, 0) = 1 OR ISNULL(ccw_hypertension, 0) = 1
	OR ISNULL(ccw_stroke, 0) = 1 OR ISNULL(ccw_hyperlipid, 0) = 1
	OR ISNULL(ccw_heart_failure, 0) = 1	OR ISNULL(ccw_atrial_fib, 0) = 1
	THEN 1 ELSE 0 END AS [ccw_cvd]
, ISNULL(ccw_asthma, 0) AS [ccw_asthma]
, ISNULL(ccw_copd, 0) AS [ccw_copd]
, CHRON_missDat
FROM CTE AS a
PIVOT
(
	MAX([flag])
	FOR [ccw_desc] IN ([ccw_diabetes]
	, [ccw_ischemic_heart_dis]
	, [ccw_mi]
	, [ccw_hypertension]
	, [ccw_stroke]
	, [ccw_hyperlipid]
	, [ccw_heart_failure]
	, [ccw_atrial_fib]
	, [ccw_asthma]
	, [ccw_copd])
) AS P
RIGHT JOIN FLAG AS c ON p.id_mcaid = c.p1_id AND p.auth_no = c.auth_no;
