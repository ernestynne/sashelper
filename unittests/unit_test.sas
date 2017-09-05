/*********************************************************************************************************
DESCRIPTION: batch of unit tests for the si data foundation
get_oversample
get_options
get_collinearity

INPUT:
si_source_path = location where you have stored the files

OUTPUT:
see each assert statement

AUTHOR: E Walsh

DEPENDENCIES: 

NOTES: should be run indepdently first as it kills all temp files in work 

HISTORY: 
02 Aug 2017 EW added variable type check to ensure char variables arent treated as numeric
08 May 2017 EW v1
*********************************************************************************************************/

/* setup path */
%let si_source_path = ;

/*********************************************************************************************************/
/* load all the macros */
options obs = MAX mvarsize = max pagesize = 132
	append =(sasautos = ("&si_source_path.\sasautos"));


/********************* get_oversample **********************/
data work._temp_bmt;
	set sashelp.bmt;

	if _N_ < 120 then
		status = 0;
run;

/* assert: sampled dataset using the default seed of 12345 */
%get_oversample (
	ds_in           = work._temp_bmt, 
	ds_out          = _temp_bmt_os1,
	target_variable = status);

/* assert: sampled dataset using a custom seed - should get different records to the above */
%get_oversample (
	ds_in           = work._temp_bmt, 
	ds_out          = _temp_bmt_os2,
	target_variable = status,
	set_seed        = 98765);

/* assert: returns the full dataset as level 0 is not the rare event */
%get_oversample (
	ds_in            = work._temp_bmt, 
	ds_out           = _temp_bmt_os3,
	rare_event_level = 0,
	target_variable  = status);

/* checkException: In get_oversample.sas - target_variable required to perform oversampling*/
%get_oversample (
	ds_in    = work._temp_bmt, 
	ds_out   = _temp_bmt_os4,
	set_seed = 98765);


/********************* get_options **********************/

/* assert: options should be nofullstimer, msglevel=n, nomlogic, nomprint */
%get_options(
	local_optimise_flag = False,
	local_debug_flag    = False);

proc options option=(fullstimer msglevel mlogic mprint);
run;

/* assert: options should be fullstimer, msglevel=i, mlogic, mprint */
%get_options(
	local_optimise_flag = True,
	local_debug_flag    = True);

proc options option=(fullstimer msglevel mlogic mprint);
run;

/* assert: options should be fullstimer, msglevel=i, nomlogic, nomprint */
%get_options(
	local_optimise_flag = True,
	local_debug_flag    = False);

proc options option=(fullstimer msglevel mlogic mprint);
run;

/* assert: options should be nofullstimer, msglevel=n, mlogic, mprint */
%get_options(
	local_optimise_flag = False,
	local_debug_flag    = True);

proc options option=(fullstimer msglevel mlogic mprint);
run;

/* checkException: In get_options - local_debug_flag. must be one of {True | False} */
%get_options(
	local_optimise_flag = True,
	local_debug_flag    = Y);

/* checkException: In get_options - local_optimise_flag. must be one of {True | False} */
%get_options(
	local_optimise_flag = N,
	local_debug_flag    = True);

/********************* get_var_type **********************/

/* assert: table work.demographics_var_type is created and two macro variables one containing the categorical
variables and one containing the numeric variables. These lists should *exclude* id and iso */
data work.demographics;
	set sashelp.demographics (drop= name);
run;

/* assert: table work.demographics_var_type is created and two macro variables one containing the categorical
variables and one containing the numeric variables. These lists should *exclude* id and iso also contains
all the intermediate tables starting with _temp_ for debugging */
%get_var_type (
	ds_in            = work.demographics,
	ds_out           = work.demographics_var_type,
	exc_vars         = id iso,
	cutoff_level     = 30,
	cat_list_name    = cat_vars,
	num_list_name    = num_vars,
	local_debug_flag = True);

%put cat_vars: &cat_vars;
%put num_vars: &num_vars;

/* assert: table work.demographics_var_type is created and two macro variables one containing the categorical
variables and one containing the numeric variables. These lists should *exclude* id and iso */
%get_var_type (
	ds_in         = work.demographics,
	ds_out        = work.demographics_var_type,
	exc_vars      = 'id' 'iso',
	cutoff_level  = 30,
	cat_list_name = cat_vars,
	num_list_name = num_vars);

%put cat_vars: &cat_vars;
%put num_vars: &num_vars;

/* assert: table work.demographics_var_type is created and two macro variables one containing the categorical
variables and one containing the numeric variables. These lists should *exclude* id and iso */
%get_var_type (
	ds_in         = work.demographics,
	ds_out        = work.demographics_var_type,
	exc_vars      = "id, iso",
	cutoff_level  = 30,
	cat_list_name = cat_vars,
	num_list_name = num_vars);

%put cat_vars: &cat_vars;
%put num_vars: &num_vars;

/* assert: table work.demographics_var_type is created and two macro variables one containing the categorical
variables and one containing the numeric variables. These lists should *include* id and iso */
%get_var_type (
	ds_in         = work.demographics,
	ds_out        = work.demographics_var_type,
	exc_vars      =,
	cutoff_level  = 30,
	cat_list_name = cat_vars,
	num_list_name = num_vars);

%put cat_vars: &cat_vars;
%put num_vars: &num_vars;

/********************* get_collinearity **********************/

/* assert: tables demographics_vif, demographics_collint and demographics_collinoint with dummy variables for region and
continent and the numeric variables*/
/* design matrix does not have dummy variables for the reference levels EUR and 93 */
%get_collinearity(
	ds_in            = work.demographics,
	uid              = id,
	cat_vars         = region cont,
	ref_levels       = "EUR" "93",
	num_vars         = &num_vars.,
	local_debug_flag = True);

/* assert: tables demographics_vif, demographics_collint and demographics_collinoint with dummy variables for region and
continent and the numeric variables*/

/* notes in the log
NOTE: In get_collinearity - the original exclusion list is: EUR 93
NOTE: In get_collinearity - the quoted comma separated list is: 'EUR' '93' */
%get_collinearity(
	ds_in            = work.demographics,
	uid              = id,
	cat_vars         = region cont,
	ref_levels       = EUR 93,
	num_vars         = &num_vars.,
	local_debug_flag = True);

/* assert: tables demographics_vif, demographics_collint and demographics_collinoint with many rows to represent the dummy
cat variables and the numeric variables*/
%get_collinearity(
	ds_in            = work.demographics,
	uid              = id,
	cat_vars         = &cat_vars.,
	num_vars         = &num_vars.,
	local_debug_flag = True);

/* assert: tables demographics_vif, demographics_collint and demographics_collinoint with rows to represent 
the numeric variables*/
%get_collinearity(
	ds_in            = work.demographics,
	uid              = id,
	cat_vars         =,
	num_vars         = &num_vars.,
	local_debug_flag = True);

/********************* get_woe **********************/
/* assert: table &ds_out with variable &var_in._woe containing the weights of evidence */
%get_woe (
	ds_in            = sashelp.bmt,
	ds_out           = work.bmt_woe,
	target           = status,
	target_type      = BIN,
	var_in           = group,
	local_debug_flag = True);

/* assert: table &ds_out with variable &var_in._woe containing the weights of evidence */
%get_woe (
	ds_in            = sashelp.bmt,
	ds_out           = work.bmt_woe,
	target           = T,
	target_type      = INT,
	var_in           = group,
	local_debug_flag = True);

/* checkException: In get_woe - target_measure must be one of BIN or INT */
%get_woe (
	ds_in            = sashelp.bmt,
	ds_out           = work.bmt_woe,
	target           = T,
	target_type      = NOM,
	var_in           = group,
	local_debug_flag = True);

/********************* get_varclus **********************/

/* assert: 5 clusters with best variables AgeAtDeath Systolic Weight Cholesterol Height */
%get_varclus(
	ds_in = sashelp.heart);

/* assert: oblique principal component cluster analysis table with maxeigen = 1.0*/
%get_varclus(
	ds_in     = sashelp.heart,
	max_eigen = 1.0);

/* assert: oblique principal component cluster analysis table with maxeigen = 1.0
 and 3 clusters with best variables AgeAtDeath Systolic Weight */
%get_varclus(
	ds_in       = sashelp.heart,
	max_eigen   = 1.0,
	max_cluster = 4);

/* assert: oblique principal component cluster analysis table with maxeigen = 1.0
 and 3 clusters with best variables AgeAtDeath Systolic Weight 
require mprint and mlogic to confirm that the model hierarchy option hasnt been used*/
%get_varclus(
	ds_in              = sashelp.heart,
	max_eigen          = 1.0,
	max_cluster        = 4,
	maintain_hierarchy = False);

/* assert: oblique principal component cluster analysis table with maxeigen = 1.0
    and 3 clusters with best variables AgeAtDeath Systolic Weight 
	and two tables _temp_fill_in_clusters and _temp_final_rsq */
%get_varclus(
	ds_in              = sashelp.heart,
	max_eigen          = 1.0,
	max_cluster        = 4,
	maintain_hierarchy = False,
	local_debug_flag   = True);

