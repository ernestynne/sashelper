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

Unit tests appear to be catching all the combinations of exc_vars if there are some exceptions raised
then regular expressions may be required e.g. prxmatch('/[,]/', exc_vars) prxmatch('/["]/', exc_vars)

AUTHOR: 
E Walsh

HISTORY: 
27 Jul 2017 EW v1
*********************************************************************************************************/
%macro get_var_type (ds_in =, ds_out =, exc_vars=,  cutoff_level=30,
			cat_list_name = cat_vars, num_list_name = num_vars, local_debug_flag = False);
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
	%put ......local_debug_flag: &local_debug_flag;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;

	/* return a list of categorical and numeric variables */
	%global &cat_list_name &num_list_name;

	/* double check that the exclusion list */
	/* first check if the exclusion list is empty */
	%local is_exc_empty quoted_exc_vars;

	/* this returns 1 if the exc_vars is empty and zero if it is not */
	%let is_exc_empty =  %sysevalf(%superq(exc_vars)=,boolean);

	/* if the list is not empty tidy it up in preparation for subsetting the datasets down stream */
	%if is_exc_empty ~= 1 %then
		%do;
			/* apply quotes so that it will not be mistaken as multiple arguments in subsequent functions */
			%let quoted_exc_vars = %sysfunc(quote(%bquote(&exc_vars)));

			/* compress blank spaces put commas between the variables and quotes around the names */
			/* this will allow it to be used in the where clause below */
			data _null_;
				/* first remove any quotes and commas so that there is no doubling up */
				clean_exc_vars = compress(&quoted_exc_vars, ',"','P');

				/* then ensure we have a comma separated list for where clauses */
				quote_separated_list = cats("'", tranwrd(cats(compbl(clean_exc_vars)), " ", "','"),"'");
				call symput('quote_separated_list',left(trim(quote_separated_list)));
			run;

			/* double check */
			%put NOTE: In get_var_type - the original exclusion list is: &exc_vars;
			%put NOTE: In get_var_type - the quoted comma separated list is: &quote_separated_list;
		%end;

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
	proc sql noprint;
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

	/*clean_up */
	%if &local_debug_flag. = False %then %do;
		proc datasets lib=work;
			delete _temp_: ;
		run;
	%end;

%mend;
