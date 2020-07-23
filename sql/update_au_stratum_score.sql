INSERT INTO kcrsn.au_stratum_score
SELECT au_stratum_id
, metric
, value
, score
, missing_data
, override_ind
, CURRENT_TIMESTAMP AS post_stamp
, NULL AS modify_stamp
FROM #au_stratum_score_temp
