INSERT INTO kcrsn.au_stratum_sda
SELECT auth_no
, start_date
, end_date
, sda
, enroll_days
, hrs_expected
, svc_hrs
, svc_hrs_prorated
, CURRENT_TIMESTAMP AS post_stamp
, NULL AS modify_stamp
, prev_auth_no
FROM #au_stratum_sda_temp
