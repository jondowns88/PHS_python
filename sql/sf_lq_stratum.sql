WITH strats AS(
	SELECT a.au_stratum_id
	, a.auth_no
	, a.start_date
	, a.end_date
	, a.strat_level
	, a.stratum_sda_id
	, b.start_date AS sda_start
	, b.end_date AS sda_end
	, b.auth_no AS first_sda_auth
	, b.prev_auth_no AS second_sda_auth
	FROM au_stratum AS a
	INNER JOIN au_stratum_sda AS b ON a.stratum_sda_id = b.stratum_sda_id
	WHERE a.start_date BETWEEN {qtr_start} AND {qtr_end}
),
piv_dat AS(
	SELECT DISTINCT *
	FROM
	(
		SELECT DISTINCT a.auth_no
		, b.strat_level
		, 1 AS flag
		FROM strats AS a
		LEFT JOIN au_stratum AS b ON a.first_sda_auth = b.auth_no
		WHERE b.start_date BETWEEN a.sda_start AND a.sda_end
			OR b.end_date BETWEEN a.sda_start AND a.sda_end

		UNION ALL

		SELECT DISTINCT a.auth_no
		, b.strat_level
		, 1 AS flag
		FROM strats AS a
		LEFT JOIN au_stratum AS b ON a.second_sda_auth = b.auth_no
		WHERE b.start_date BETWEEN a.sda_start AND a.sda_end
			OR b.end_date BETWEEN a.sda_start AND a.sda_end
	) AS a
),
piv_dat2 AS(
	SELECT auth_no
	, CASE WHEN L IS NOT NULL AND M IS NULL AND H IS NULL THEN 'L'
	WHEN L IS NULL AND M IS NOT NULL AND H IS NULL THEN 'M'
	WHEN L IS NULL AND M IS NULL AND H IS NOT NULL THEN 'H'
	WHEN L IS NOT NULL AND M IS NOT NULL AND H IS NULL THEN 'L, M'
	WHEN L IS NOT NULL AND M IS NULL AND H IS NOT NULL THEN 'L, H'
	WHEN L IS NULL AND M IS NOT NULL AND H IS NOT NULL THEN 'M, H'
	WHEN L IS NOT NULL AND M IS NOT NULL AND H IS NOT NULL THEN 'L, M, H'
	WHEN L IS NULL AND M IS NULL AND H IS NULL THEN 'NONE'
	ELSE '' END AS sda_strats
	FROM
	(
		SELECT *
		FROM piv_dat AS a
		PIVOT(
			MAX(flag) FOR [strat_level] IN([L],[M],[H])
		) AS p
	) AS a
)
SELECT a.auth_no
, first_sda_auth
, second_sda_auth
, COALESCE(b.sda_strats, 'NONE') AS sda_strats
FROM strats AS a
LEFT JOIN piv_dat2 AS b ON a.auth_no = b.auth_no