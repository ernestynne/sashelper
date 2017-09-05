/*********************************************************************************************************
DESCRIPTION: Calculates the collinearity of a model once it has been built outputs variance inflation 
factors and also the eigenvalue conditions indexes to specifically identify which variables are 
correlated with each other it is then up to the modeller to interpret these and decide the course of 
action 

INPUT: 
in_ds    = dataset containing variables
uid      = unique id variable
cat_vars = macro variable containing a list of categorical variables to check
num_vars = macro variable containing a list of continuous variables to check

OUTPUT:
work.&ds_in._collin         = condition index table
work.&ds_in._collinnoint    = condition index table with intercept adjusted out
work.&ds_in._vif            = table that will contain the variance inflation factors

DEPENDENCIES: 
get_var_type can be used to build cat_vars and num_vars

NOTES: we use VIF > 10 as an indicator of collinearity and if the last condition index > 100 then there
is strong collinearity

AUTHOR: 
E Walsh

HISTORY: 
31 Jul 2017 EW improved to make use of _trg_ind
01 Aug 2016 EW rewrote to handle numeric variables as well
15 Jul 2016 EW v1
*********************************************************************************************************/
%macro get_collinearity(ds_in =, uid =, cat_vars =, ref_levels =, num_vars =, local_debug_flag = False);
	%put ********************************************************************;
	%put --------------------------------------------------------------------;
	%put ---------------------------sashelper--------------------------------;
	%put ..........start_run_at: %sysfunc(datetime(), datetime20.);
	%put --------------------------------------------------------------------;
	%put -----------------get_collinearity: Inputs---------------------------;
	%put .................ds_in: &ds_in;
	%put ...................uid: &uid;
	%put ..............cat_vars: &cat_vars;
	%put ............ref_levels: &ref_levels;
	%put ..............num_vars: &num_vars;
	%put ......local_debug_flag: &local_debug_flag;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;

	/* set up some macro variables for sorting out the reference levels */
	%local is_ref_levels_empty quoted_ref_levels;

	/* this returns 1 if the exc_vars is empty and zero if it is not */
	%let is_cat_vars_empty =  %sysevalf(%superq(cat_vars)=,boolean);

	/* this returns 1 if the ref_levels is empty and zero if it is not */
	%let is_ref_levels_empty =  %sysevalf(%superq(ref_levels)=,boolean);

	/* first create a design matrix for the categorical variables */
	%if &is_cat_vars_empty ~= 1 %then
		%do;

			proc transreg data= &ds_in. design;
				model class(&cat_vars. / effect zero = "EUR") ;
					output out=work._temp_design_matrix (drop= &cat_vars. _type_ _name_ );
					id &uid;
			run;

		%end;

	/* add the dummy variables to the dataset */
	proc sql nowarn;
		create table _temp_ds_in_dummy_var as
			select  a.*, b.*
				from &ds_in a left join work._temp_design_matrix b
					on a.&uid = b.&uid;
	quit;

	/* this proecdure stores the list of dummy variable names */
	%put NOTE: In get_collineraity - transreg dummy vars: &_trgind;

	/* the condition index output is likely to be large and difficult
	to read on the screen so output it to a table */
	ods trace on;
	ods output CollinDiag = &ds_in._collin
		CollinDiagNoInt = &ds_in._collinoint
		ParameterEstimates = &ds_in._vif;

	proc reg data= work._temp_ds_in_dummy_var;
collinearity:
		model Intercept = %if &is_cat_vars_empty ~= 1 %then

			%do;
				&_trgind.
			%end;

		&num_vars. / vif collin collinoint;
	run;

	ods trace off;

	/*clean_up */
	%if &local_debug_flag. = False %then
		%do;

			proc datasets lib=work;
				delete _temp_:;
			run;

		%end;
%mend;