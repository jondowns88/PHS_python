/********************************************************************
*	phs_stratum_score.sql
*	By: Jon Downs
*	1/23/2020
*	Purpose: Create line-item risk scores given a pop infile from R
*********************************************************************/
/*UPDATES*/
--2019-01-29 (JD): The previous iteration was excluding variables in the pop model that were missing (as there was no match).
	--	We could just do a LEFT JOIN, but that would then include results for variables not in the specific POPMODEL (i.e. ASAM scores for MH benes)
	-- So, I created a CTE as a first step: this will inner join to the pop model table and restrict to rows that would be in the POPMODEL for that benefit

/*Create a CTE to restrict to covariates in the population model: need to make sure it is the right benefit type, age group, and model version for the iteration*/
WITH inFile AS(
	SELECT DISTINCT a.*
	FROM {`temp_tab_in`} AS a
	INNER JOIN cd_stratum_pop_model AS b ON 
	/*Benefit type*/
	a.program = b.program
		AND a.age_group = b.age_group /*Age groups (A/C/G) */
		AND a.metric = b.metric /*Metrics*/
		AND calc_date BETWEEN b.start_date AND b.end_date /*Correct version of model for the date*/
)
/*Join to pop model to yield the score for this metric*/
SELECT a.auth_no
, a.program
, a.age_group
, a.calc_date
, a.metric
, a.value
, ISNULL(b.score, 0) AS score, a.missDat
FROM inFile AS a
	LEFT JOIN cd_stratum_pop_model AS b ON 
		a.program = b.program
			AND a.age_group = b.age_group /*Age group*/
			AND a.metric = b.metric /*Same metric for score and value*/
			AND a.value BETWEEN range_low AND range_high /*Within the value ranges to be assigned this score*/
			AND calc_date BETWEEN b.start_date AND b.end_date /*Correct version of model for the calc date*/
ORDER BY a.auth_no, a.metric
