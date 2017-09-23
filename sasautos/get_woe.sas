/*********************************************************************************************************
DESCRIPTION: Calculates the weights of evidence for a variable with a binary or continuous target

INPUT: 
ds_in            = input table
target           = name of the target variable a numeric variable with values {0 | 1}
target_type      = whether the target is binary or interval {BIN | INT}
var_in           = the variable that we wish to convert into an woe
local_debug_flag = flag for debugging when set to true all _temp_ datasets are retained

OUTPUT:
ds_out         = output table specifying all the variable type metadata

DEPENDENCIES: 

NOTES: 

AUTHOR: 
E Walsh

HISTORY: 
03 Aug 2017 EW macro-ised
01 Aug 2016 EW rewrote to handle numeric variables as well
15 Jul 2016 EW v1
*********************************************************************************************************/
%macro get_woe (ds_in =, ds_out =, target = , target_type = , var_in =, smooth = 30, local_debug_flag = False);
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
	%put ................var_in: &var_in;
	%put ................smooth: &smooth;
	%put ......local_debug_flag: &local_debug_flag;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;

	%if not (&target_type = BIN or  &target_type = INT) %then
		%do;
			%put ERROR: In get_woe - target_measure must be one of BIN or INT;
		%end;
	%else
		%do;
			%if &target_type = BIN %then
				%do;
					/* for a binary target */
					/* woe = log ( n_1i + n_1 x smooth)/(n_0i + n_0 x smooth) */
					/* n_1i is a count of the target being equal to 1 for level i */
					/* n_0i is a count of the target being equal to zero for level i */
					/* n_0i + n_1i = n_i total count for level i */
					/* p_1 is the proportion of the target variable with 1 */
					/* 1-p_1 = p_0 is the proportion of the target variable with 0 */
					proc sql noprint;
						/* warning if non standard target numbers are used i.e. anything other than 1 and 0
																					then this will not work */
						select mean(&target.) into: p_1
							from &ds_in.
								quit;

					proc means data = &ds_in.;
						class &var_in.;
						var  &target.;
						output out = work._temp_calculation (rename=(_freq_ = n_i)
							where = ( _type_ = 1))
							sum = n_1i;
					run;

					proc sql;
						create table _temp_woe as
							select a.*
								/* since this is a binary outcome the number of zeroes for each level 
								is the total number of each level less the number of 1s for that level */

						,log((a.n_1i + &p_1. * &smooth.)/((a.n_i - a.n_1i) + (1-&p_1.) * &smooth.)) as &var_in._woe
						from work._temp_calculation a;
					quit;

					proc sql;
						create table &ds_out. as
							select a.*
								,b.&var_in._woe
							from &ds_in a left join _temp_woe b
								on a.&var_in. = b.&var_in.;
					quit;

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
						create table work._temp_calculation as
							select &var_in.
								,mean(&target.) as y_i
								,count(&var_in.) as n_i
							from &ds_in.
								group by &var_in.;
					quit;

					proc sql;
						create table _temp_woe as
							select a.*
								/* since this is a binary outcome the number of zeroes for each level 
								is the total number of each level less the number of 1s for that level */

						,(&smooth. * &y_overall. + n_i * y_i) / (&smooth. + n_i) as &var_in._woe
						from work._temp_calculation a;
					quit;

					proc sql;
						create table &ds_out. as
							select a.*
								,b.&var_in._woe
							from &ds_in a left join _temp_woe b
								on a.&var_in. = b.&var_in.;
					quit;

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
