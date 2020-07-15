WITH mgrs AS(
	SELECT a.kcid
	, a.agency_id
	, a.kcid_mgr
	, a.case_mgr_type
	FROM mp_mgr_link AS a
	INNER JOIN(
		SELECT kcid
		, agency_id
		, case_mgr_type
		, MAX(post_stamp) AS post_stamp
		FROM mp_mgr_link
		WHERE case_mgr_type = 'M'
		GROUP BY kcid, agency_id, case_mgr_type
	) AS b ON a.kcid = b.kcid
		AND a.agency_id = b.agency_id
		AND a.post_stamp = b.post_stamp
		AND a.case_mgr_type = b.case_mgr_type
	WHERE a.kcid IN(SELECT kcid FROM {`temp_tab_in`})
),
new_data AS(
	SELECT a.kcid
	, a.agency_id
	, a.case_mgr_type
	, a.kcid_mgr AS mgr_id
	, b.given_names AS mgr_first_name
	, b.surname AS mgr_last_name
	FROM mgrs AS a
	INNER JOIN g_person AS b ON a.kcid_mgr = b.kcid
)
SELECT DISTINCT a.*
, b.mgr_id
, b.mgr_first_name
, b.mgr_last_name
FROM {`temp_tab_in`} AS a
LEFT JOIN new_data AS b ON a.kcid = b.kcid
	AND a.agency_id = b.agency_id
	AND a.case_mgr_type = b.case_mgr_type

