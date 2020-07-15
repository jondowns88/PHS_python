SELECT kcid
, given_names AS first_name
, surname AS last_name
, dob
FROM g_person
WHERE kcid IN(SELECT DISTINCT kcid FROM {`temp_tab_in`})