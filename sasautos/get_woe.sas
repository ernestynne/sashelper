/*********************************************************************************************************
DESCRIPTION: Calculates the weights of evidence for a variable with a binary or continuous target

INPUT: 
ds_in            = input table
target           = name of the target variable
target_type      = whether the target is binary or interval {BIN | INT}
var_in           = 
local_debug_flag = flag for debugging when set to true all _temp_ datasets are retained

OUTPUT:
ds_out         = output table specifying all the variable type metadata

DEPENDENCIES: 

NOTES: 

AUTHOR: 
E Walsh

HISTORY: 
03 Aug 2017 macro-ised
01 Aug 2016 rewrote to handle numeric variables as well
15 Jul 2016 v1
*********************************************************************************************************/
%macro get_woe (ds_in =, ds_out =, target = , target_type = , var_in =, local_debug_flag = False);
	%put ********************************************************************;
	%put --------------------------------------------------------------------;
	%put ---------------------------sashelper--------------------------------;
	%put ..........start_run_at: %sysfunc(datetime(), datetime20.);
	%put --------------------------------------------------------------------;
	%put ----------------------get_woe: Inputs-------------------------------;
	%put .................ds_in: &ds_in;
	%put ................ds_out: &ds_out;
	%put ................target: &target;
	%put ...........target_type: &target_type;
	%put ......local_debug_flag: &local_debug_flag;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;

	%if &target_type ~= BIN or  &target_type ~= BIN %then
		%do;
			%put ERROR: In get_woe - target_measure must be one of BIN or INT;
		%end;
	%else
		%do;
			%if &target_type = BIN %then
				%do;

					proc sort data =  &ds_in.;
						by &var_in.;
					run;

					/* for a binary target */
					/* woe = log ( n_1i + n_1 x smooth)/(n_0i + n_0 x smooth) */
					/* n_1i is a count of the target being equal to 1 for level i */
					/* n_0i is a count of the target being equal to zero for level i */
					/* n_1 is the total count of the target being equal to 1 */
					/* n_0 is the total count of the target being equal to 0 */
					proc sql noprint;
						select count(*) into: n_1
							from &ds_in.
								where &target.=1;
					quit;

					proc sql noprint;
						select count(*) into: n_0
							from &ds_in.
								where &target.=0;
					quit;

					/* TODO - fix this part up so that it just uses  proc means */
					/* create a join to get woe attached to the original table */

					proc sort data=&ds out=work.temp_sorted;
						by &var &target.;
					run;

					/* count the number of 1s and 0s in each level*/
					data work._temp_calculation;
						set &ds_in.;
						by &var_in. &target.;
						retain n_0i n_1i 0;

						if &target. = 1 then
							n_1i + 1;

						/* used if rather than else in case there are missing values */
						if &target. = 0 then
							n_0i + 1;

						if last.&var then
							do;
								output;
								n_0i = 0;
								n_1i = 1;
							end;
					run;

					data &ds_out.;
						set work._temp_calculation;
						woe = log((n_1i + &n_1. * &smooth.)/(n_0i + &n_0. * &smooth.));
					run;

				%end;

			%if &target_type = INT %then
				%do;
					/* for a continuous target */
					/* calculate the overall mean */
					proc sql noprint;
						select mean(&target.) into: y_overall
							from &ds_in.;
					quit;

					proc sql;
						create table _temp_n_i_y_i as
							select &var_in.
								mean(&target.) as y_i
								count(&var_in.) as n_i
							from &ds_in.
								group by &var_in.;
					quit;

					data &ds_out.;
						set _temp_n_i_y_i (where=());
						woe = (&smooth. * &y_overall. + n_i * y_i) / (&smooth. + n_i);
					run;

				%end;

			/*clean_up */
			%if &local_debug_flag. = False %then
				%do;

					proc datasets lib=work;
						delete _temp_:;
					run;

				%end;
		%end;
%mend;

data work.bmt;
	set sashelp.bmt;
run;

%get_woe (ds_in = work.bmt, ds_out =work.bmt_woe, target = status, target_type = BIN, var_in = group, local_debug_flag = False)