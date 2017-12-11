/*********************************************************************************************************
DESCRIPTION: Oversample the data so that we have a 50:50 split

INPUT: 
ds_in            = input table to be oversampled
target_variable  = name of the variable you are trying to predict - sample is stratified on this
rare_event_level = indicates which event is considered rare - default is 1
set_seed         = seed to ensure you get the same oversampled table each time - default is 12345

OUTPUT:
ds_out           = name of the oversampled table also contains sample probability and weight

DEPENDENCIES: 

NOTES: 

AUTHOR: 
E Walsh

HISTORY: 
25 Jul 2017 EW v1
*********************************************************************************************************/
%macro get_oversample (ds_in =, ds_out =, target_variable=, rare_event_level = 1, set_seed=12345);
	%put ********************************************************************;
	%put --------------------------------------------------------------------;
	%put ---------------------------sashelper--------------------------------;
	%put ..........start_run_at: %sysfunc(datetime(), datetime20.);
	%put --------------------------------------------------------------------;
	%put ------------------get_oversample: Inputs----------------------------;
	%put .................ds_in: &ds_in;
	%put ................ds_out: &ds_out;
	%put .......target_variable: &target_variable;
	%put ......rare_event_level: &rare_event_level;
	%put ..............set_seed: &set_seed;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;
	%local local_rare_event_count;

	%if &target_variable.= %then
		%do;
			%put ERROR: In get_oversample.sas - target_variable required to perform oversampling;
		%end;
	%else
		%do;

			proc sql noprint;
				select count(&target_variable.) into: rare_event_count
					from &ds_in.
						where &target_variable. = &rare_event_level.;
			quit;

			proc surveyselect data = &ds_in. 
				out = &ds_out. (rename=(selectionprob = selection_prob samplingweight = sampling_weight))
				method = srs
				/* this is the number in each strata not the overall sample size */
				n = &rare_event_count.
				seed= &set_seed.
				noprint
				selectall;
				strata &target_variable.;
			run;

		%end;
%mend;
