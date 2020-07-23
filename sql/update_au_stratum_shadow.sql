INSERT INTO kcrsn.au_stratum_shadow
SELECT *
FROM kcrsn.au_stratum
WHERE au_stratum_id NOT IN (SELECT au_stratum_id FROM kcrsn.au_stratum_shadow)