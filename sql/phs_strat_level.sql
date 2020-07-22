SELECT a.auth_no
  , a.program
  , a.age_group
  , a.calc_date
  , a.score
  , a.age
  , a.missDat
  , b.strat_level
  , b.svc_hrs_req
  FROM #phs_strat_level AS a
  LEFT JOIN cd_stratum_tier AS b ON a.program = b.program
	AND a.age_group = b.age_group
	AND a.total_score BETWEEN range_low AND range_high
	AND calc_date BETWEEN start_date AND end_date