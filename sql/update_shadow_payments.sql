UPDATE kcrsn.au_stratum
SET sda_rule = 'SHA'
, sda_pay_multiplier = 1.00
FROM kcrsn.au_stratum
WHERE start_date = '2020-07-01'
	AND sda_rule != 'SHA