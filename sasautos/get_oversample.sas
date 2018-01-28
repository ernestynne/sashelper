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
09 Jan 2018 EW extended to allow user to pick the max of the rare level or a cut off number of records
25 Jul 2017 EW v1
*********************************************************************************************************/
%macro get_oversample (ds_in =, ds_out =, target_variable=, rare_event_level = 1, 
max_obs_per_strata = 500000, set_seed=12345, local_debug_flag = False );
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
	%put ....max_obs_per_strata: &rare_event_level;
	%put ..............set_seed: &set_seed;
	%put ......local_debug_flag: &local_debug_flag;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;
	%local local_rare_event_count;
	%local prior_0 prior_1 subset_0 subset_1;

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

			/* we dont specify n as the max_obs_per_strata to begin with as that doesnt guarantee a ~50:50 split
						between the outcomes */

			/* this way guarantees that split and also ensures that for the more common primary
					outcomes there isnt a huge number of records to deal with */
			%if %sysevalf(&rare_event_count. > &max_obs_per_strata.) %then
				%let rare_event_count = &max_obs_per_strata.;;

			proc surveyselect data = &ds_in. 
				out = _temp_ (rename=(selectionprob = selection_prob samplingweight = sampling_weight))
				method = srs
				/* this is the number in each strata not the overall sample size */
				n = &rare_event_count.
				seed= &set_seed.
				noprint
				selectall;
				strata &target_variable.;
			run;

			/* create a set of weights to adjust for oversampling */
			proc freq data =  &ds_in. noprint;
				table &target_variable. / out =  _temp_prior_&rare_event_level. 
					(where=(&target_variable. = &rare_event_level.) rename=(percent=prior_percent));
			run;

			proc freq data = _temp_ noprint;
				table &target_variable. / out =  _temp_subset_&rare_event_level. 
					(where=(&target_variable. = &rare_event_level.) rename=(percent=subset_percent));
			run;

			data &ds_out. (drop = prior_percent subset_percent);
				set _temp_;

				if _n_=1 then
					set  _temp_prior_&rare_event_level.(keep = prior_percent);

				if _n_=1 then
					set  _temp_subset_&rare_event_level.(keep = subset_percent);

				/* constructing the weights */
				/* we are using a weight to reverse out the effects of oversampling - ie we will decrease the intercept 
					and the probabilities */

				/* the original dataset had 0.1/0.9 as the proportions of primary and secondary outcomes. We needed more 
					emphasis placed on the rarer target so it has now gone to 0.5/0.5, the primary propotion has increased
					so the weight needs	to decrease and be <1 to reverse the oversampling this will ensure that the 
					adjusted primary probability is smaller than the unadjusted primary probability, the secondary 
					proportion has decreased from 0.9 to 0.5 so the weight should be >1 */
				if &target_variable. = &rare_event_level. then
					oversampling_weight = (prior_percent/100)/(subset_percent/100);
				else oversampling_weight = (1-(prior_percent/100))/(1-(subset_percent/100));
			run;

				/*clean_up */
	%if &local_debug_flag. = False %then
		%do;

			proc datasets lib=work;
				delete _temp_:;
			run;

		%end;

		%end;
%mend;
