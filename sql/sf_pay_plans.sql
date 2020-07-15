/*Most recent non-missing payment plan*/
WITH pays AS(
	SELECT *
	FROM
	(
		SELECT auth_no
		, paid_plan
		, DATEFROMPARTS(payment_year, payment_month, 1) AS pay_date
		, ROW_NUMBER() OVER(PARTITION BY auth_no ORDER BY DATEFROMPARTS(payment_year, payment_month, 1) DESC) AS rn
		FROM fm_payment_plan
		WHERE auth_no IN(SELECT DISTINCT auth_no FROM {`temp_tab_in`})
		  AND paid_plan IS NOT NULL
	) AS a
	WHERE rn = 1
),
/*Initial payment plan (use if missing)*/
miss_pays AS(
	SELECT *
	FROM
	(
		SELECT auth_no
		, initial_plan
		, DATEFROMPARTS(payment_year, payment_month, 1) AS pay_date
		, ROW_NUMBER() OVER(PARTITION BY auth_no ORDER BY DATEFROMPARTS(payment_year, payment_month, 1) DESC) AS rn
		FROM fm_payment_plan
		WHERE auth_no IN(SELECT DISTINCT auth_no FROM {`temp_tab_in`})
		  AND initial_plan IS NOT NULL
	) AS a
	WHERE rn = 1
)
SELECT a.auth_no
, COALESCE(b.paid_plan, c.initial_plan) AS paid_plan
, CASE WHEN b.auth_no IS NULL THEN 'Y' ELSE 'N' END AS pay_manip
, COALESCE(b.pay_date, c.pay_date) AS pay_date
FROM {`temp_tab_in`} AS a
LEFT JOIN pays AS b ON a.auth_no = b.auth_no
LEFT JOIN miss_pays AS c ON a.auth_no = c.auth_no