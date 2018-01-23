/*********************************************************************************************************
DESCRIPTION: Calculates the weights of evidence style value for a variable with a binary or
continuous target

INPUT: 
ds_in                  = input table
partition_where_clause = if training and validation datasets are use this where clause can be used to
identify which observations are used to construct the woe
ds_woe_out             = name of the weights of evidence dataset default is _temp_woe which will not be retained if
you have local_debug_flag set to False
target                 = name of the target variable a numeric variable with values {0 | 1}
target_type            = whether the target is binary or interval {BIN | INT}
var_in                 = the variable that we wish to convert into an woe
smooth                 = smoothing parameter applied to the target very large values will cause woe for the different groups
                         to become more similar
local_debug_flag       = flag for debugging when set to true all _temp_ datasets are retained {True | False}

　
OUTPUT:
ds_out         = output table specifying all the variable type metadata

DEPENDENCIES: 

NOTES: 

AUTHOR: 
E Walsh

HISTORY: 
17 Jan 2018 EW added extra functionality to handle data partitions and retaining woe table
03 Aug 2017 EW macro-ised
01 Aug 2016 EW rewrote to handle numeric variables as well
15 Jul 2016 EW v1
*********************************************************************************************************/
%macro get_woe (ds_in =, partition_where_clause =, ds_woe_out = _temp_woe, ds_out =, target = , 
			target_type = , var_in =, smooth = 30, local_debug_flag = False);
	%put ********************************************************************;
	%put --------------------------------------------------------------------;
	%put ---------------------------sashelper--------------------------------;
	%put ..........start_run_at: %sysfunc(datetime(), datetime20.);
	%put --------------------------------------------------------------------;
	%put ----------------------get_woe: Inputs-------------------------------;
	%put .................ds_in: &ds_in;
	%put partition_where_clause: &partition_where_clause;
	%put ............ds_woe_out: &ds_woe_out;
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
			%local is_wherecl_empty;

			/* this returns 1 if the exc_vars is empty and zero if it is not */
			%let is_wherecl_empty =  %sysevalf(%superq(partition_where_clause)=,boolean);

			/* these are the obs we will use to calculate the weights of evidence */
			data work._temp_;
				set &ds_in.

					%if &is_wherecl_empty ~= 1 %then
						%do;
							(where=(%str(&partition_where_clause)))
						%end;
					;
			run;

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
							from _temp_
								quit;

					proc means data = _temp_ noprint;
						class &var_in.;
						var  &target.;
						output out = work._temp_calculation (rename=(_freq_ = n_i)
							where = ( _type_ = 1))
							sum = n_1i;
					run;

					proc sql;
						create table &ds_woe_out. as
							select a.*
								/* since this is a binary outcome the number of zeroes for each level 
								is the total number of each level less the number of 1s for that level */

						,log((a.n_1i + &p_1. * &smooth.)/((a.n_i - a.n_1i) + (1-&p_1.) * &smooth.)) as &var_in._woe
						from work._temp_calculation a;
					quit;

					proc sql;
						create table _temp_out_ds_with_woe as
							select a.*
								,b.&var_in._woe
							from &ds_in a left join _temp_woe b
								on a.&var_in. = b.&var_in.;
					quit;

					/* extra step in case any of the levels are only present in the validation or test set */
					data &ds_out;
						set _temp_out_ds_with_woe;

						if missing(&var_in._woe) then
							&var_in._woe = &p_1.;
					run;

				%end;

			%if &target_type = INT %then
				%do;
					/* for a continuous target */
					/* calculate the overall mean */
					proc sql noprint;
						select mean(&target.) into: y_overall
							from _temp_;
					quit;

					proc sql;
						create table work._temp_calculation as
							select &var_in.
								,mean(&target.) as y_i
								,count(&var_in.) as n_i
							from _temp_
								group by &var_in.;
					quit;

					proc sql;
						create table &ds_woe_out. as
							select a.*
								/* since this is a binary outcome the number of zeroes for each level 
								is the total number of each level less the number of 1s for that level */

						,(&smooth. * &y_overall. + n_i * y_i) / (&smooth. + n_i) as &var_in._woe
						from work._temp_calculation a;
					quit;

					proc sql;
						create table _temp_out_ds_with_woe as
							select a.*
								,b.&var_in._woe
							from &ds_in a left join _temp_woe b
								on a.&var_in. = b.&var_in.;
					quit;

					/* extra step in case any of the levels are only present in the validation or test set */
					data &ds_out;
						set _temp_out_ds_with_woe;

						if missing(&var_in._woe) then
							&var_in._woe = &y_overall.;
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
