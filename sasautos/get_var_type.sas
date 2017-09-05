/*********************************************************************************************************
DESCRIPTION: Generate table of metadata regarding type of variables we have i.e. interval, categorical, 
binary, unary. Also generates macro variables listing all the categorical and numeric variables less
the ones in the exclusion list

INPUT: 
ds_in          = input table
exc_vars       = list of quoted, comma separated variables to exclude from cat_vars and int_vars
examples include the id variable and the target variable
cutoff_level   = number of levels to define a categorical variable i.e. [3, &cutoff_level)
if cutoff_level is exceeded the variable is considered interval (ie numeric)

OUTPUT:
ds_out         = output table specifying all the variable type metadata
cat_list_name  = name of the list of categorical variables excluding variables in &exc_var
num_list_name  = name of the list of numeric variables excluding variables in &exc_var

DEPENDENCIES: 
NA

NOTES:
At a later date we might want to split meta data generation info from the assigning of categorical
variables so that variable type can be run once assigning variables to a macro variable can
be run multiple times. For now it might be safer to have them together in case some downstream
data processing merges levels and the numeric and categorical variables need to be recalculated

AUTHOR: 
E Walsh

HISTORY: 
27 Jul 2017 EW v1
*********************************************************************************************************/
%macro get_var_type (ds_in = , ds_out = , exc_vars=,  cutoff_level=30,
cat_list_name = cat_vars, num_list_name = num_vars);
	%put ********************************************************************;
	%put --------------------------------------------------------------------;
	%put ---------------------------sashelper--------------------------------;
	%put ..........start_run_at: %sysfunc(datetime(), datetime20.);
	%put --------------------------------------------------------------------;
	%put -------------------get_var_type: Inputs-----------------------------;
	%put .................ds_in: &ds_in;
	%put ................ds_out: &ds_out;
	%put ..............exc_vars: &exc_vars;
	%put ..........cutoff_level: &cutoff_level;
	%put .........cat_list_name: &cat_list_name;
	%put .........num_list_name: &num_list_name;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;

	/* return a list of categorical and numeric variables */
	%global &cat_list_name &num_list_name;
 
	/* double check that the exclusion list */
	/* first check if the exclusion list is empty */
	%local is_exc_empty quoted_exc_vars;

	/* this returns 1 if the exc_vars is empty and zero if it is not */
	%let is_exc_empty =  %sysevalf(%superq(exc_vars)=,boolean);

	/* if the list is not empty check that it doesnt have commas and quotes as these are applied
	down stream */

/*	%if is_exc_empty ~= 1 %then %do;*/
	data _null_;
		is_comma_found = prxmatch('/[,]/', exc_vars);
		is_quote_found = prxmatch('/["]/', exc_vars);
		call symput('is_comma_found',left(trim(is_comma_found)));
		call symput('is_quote_found',left(trim(is_quote_found)));
	run;

	%if &is_comma_found. ~= 0 or &is_quote_found. ~= 0 %then
		%do;
			%put ERROR: In get_var_type - exc_vars should not have commas or quotes in the list;
		%end;
	%else
		%do;
			/* wrap quotes around the exclusion list so that we can hide the spaces */
			/* this will stop the compress blank function mistaking it for multiple arguments */
			%let quoted_exc_vars = %sysfunc(quote(&exc_vars));

			/* compress blank spaces put commas between the variables and quotes around the names */
			/* this will allow it to be used in the where clause below */
			data _null_;
				length quote_separated_list $200;
				quote_separated_list = cats("'", tranwrd(cats(compbl(&quoted_exc_vars)), " ", "','"),"'");
				call symput('quote_separated_list',left(trim(quote_separated_list)));
			run;

			/* double check */
			%put the original exclusion list is: &exc_vars;
			%put the quoted comma separated list is: &quote_separated_list;
			%put any commas: &is_comma_found;
			%put any quotes: &is_quote_found;

			/* identify how many levels each variable has this will be used to determine the variable type */
			ods output nlevels = work._temp_nlevels;

			proc freq data = &ds_in. nlevels;
				table _all_ / noprint;
			run;

			proc sql;
				create table &ds_out.
					as select * 
						,
					case 
						when NNonMissLevels > &cutoff_level. then "INTERVAL"
						when NNonMissLevels between 3 and &cutoff_level. then "CATEGORICAL"
						when NNonMissLevels = 2 then "BINARY"
						when NNonMissLevels = 1 then "UNARY"
					end 
				as var_type length = 11 format = $11.
					from work._temp_nlevels;
			quit;

			/* store the categorical and numeric variables into separate macro variables so that they can
					be referenced in the modelling later on things such as ids and target variables should be excluded
					from this list using the exc var*/
			proc sql;
				select trim(tablevar) into: &cat_list_name separated  by ' '
					from &ds_out.
						where var_type = "CATEGORICAL" %if &is_exc_empty = 0 %then

					%do;
						and upcase(tablevar) not in(%upcase(&quote_separated_list.))
					%end;;

				select trim(tablevar) into: &num_list_name separated  by ' '
					from &ds_out.
						where var_type in ("BINARY","INTERVAL") %if &is_exc_empty = 0 %then

					%do;
						and upcase(tablevar) not in(%upcase(&quote_separated_list.))
					%end;;
			quit;

		%end;
%mend;

/* test */

/* assert: table work.demographics_var_type is created and two macro variables one containing the categorical
variables and one containing the numeric variables. These lists should *exclude* id and iso */
data work.demographics;
	set sashelp.demographics (drop= name);
run;

%get_var_type (ds_in = work.demographics, ds_out = work.demographics_var_type , exc_vars= id iso,  cutoff_level=30
,cat_list_name = cat_vars, num_list_name = num_vars);

%put cat_vars: &cat_vars;
%put num_vars: &num_vars;

/* checkException: In get_var_type - exc_vars should not have commas or quotes in the list*/
%get_var_type (ds_in = work.demographics, ds_out = work.demographics_var_type , exc_vars= "id" "iso",  cutoff_level=30
,cat_list_name = cat_vars, num_list_name = num_vars);


%get_var_type (ds_in = work.demographics, ds_out = work.demographics_var_type , exc_vars= "id, iso",  cutoff_level=30
,cat_list_name = cat_vars, num_list_name = num_vars);

/* assert: table work.demographics_var_type is created and two macro variables one containing the categorical
variables and one containing the numeric variables. These lists should *include* id and iso */
%get_var_type (ds_in = work.demographics, ds_out = work.demographics_var_type , exc_vars=,  cutoff_level=30
,cat_list_name = cat_vars, num_list_name = num_vars);