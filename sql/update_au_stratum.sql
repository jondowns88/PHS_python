INSERT INTO kcrsn.au_stratum
SELECT auth_no
, calc_date
, start_date
, end_date
, total_score
, strat_level
, age_group
, special_population
, language_differential
, 1.00 AS sda_pay_multiplier
, missing_data
, override_status
, CURRENT_TIMESTAMP AS post_stamp
, 'SHA' AS sda_rule
, NULL AS modify_stamp
, NULL as stratum_sda_id
FROM #au_stratum_temp
