/*********************************************************************************************************
DESCRIPTION: partition the data in training, validation and test datasets

INPUT:
ds_in = input dataset
train_pro = proportion of the data assigned to the training dataset
valid_pro = proportion of the data assigned to the validation dataset
test_pro = proportion of the data assigned to the test dataset
set_seed = sampling seed to ensure you get the same partition each time
target_variable = target variable that will be used in stratification
id_variable = unique identifier - currently accepts only one column
oot_flag = perform an out of time sample {True | False}
oot_column = the time column used to perform the out of time sample
local_debug_flag = flag for debugging when set to true all _temp_ datasets are retained

OUTPUT:
ds_out = output dataset that has an extra column stating what partition the row belongs to

AUTHOR: E Walsh

DEPENDENCIES:

NOTES:
This is designed for binary targets
Code might fail if you have a continuous target due to stratification on the target variable

HISTORY:
16 Mar 2018 EW revised code to sort on random number based on QA feedback
15 Mar 2018 TN QA - code should be sorted by random number to get the right distribution between sets
30 Jan 2018 EW made rounding more consistent
12 Dec 2017 EW v1
*********************************************************************************************************/

%macro get_data_partition(ds_in = , ds_out =, train_pro = 0.7, valid_pro = 0.3, test_pro = 0.0, set_seed = 12345, id_variable = ,
			oot_flag = False, oot_column =, local_debug_flag = False);
	%put ********************************************************************;
	%put --------------------------------------------------------------------;
	%put ---------------------------sashelper--------------------------------;
	%put ..........start_run_at: %sysfunc(datetime(), datetime20.);
	%put --------------------------------------------------------------------;
	%put -----------------get_data_partition: Inputs-------------------------;
	%put .................ds_in: &ds_in;
	%put ................ds_out: &ds_out;
	%put .............train_pro: &train_pro;
	%put .............valid_pro: &valid_pro;
	%put ..............test_pro: &test_pro;
	%put ..............set_seed: &set_seed;
	%put ...........id_variable: &id_variable;
	%put ..............oot_flag: &oot_flag;
	%put ............oot_column: &oot_column;
	%put ......local_debug_flag: &local_debug_flag;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;

	/* make sure proportions are specified and they sum to 1 otherwise we will end up with and output dataset that is 
	larger than the input dataset*/
	%if (%sysevalf(&train_pro. > 1) or  %sysevalf(&valid_pro. > 1) or %sysevalf(&test_pro. > 1)) %then
		%do;
			%put ERROR: In get_data_partition - must specify proportions not percentages;
		%end;
	%else %if (%sysevalf(&train_pro. < 0) or  %sysevalf(&valid_pro. < 0) or %sysevalf(&test_pro.< 0)) %then
		%do;
			%put ERROR: In get_data_partition - negative proportions or missing values specified;
		%end;
	%else %if (%sysfunc(sum(&train_pro.,&valid_pro.,&test_pro.)) ~= 1) %then
		%do;
			%put ERROR: In get_data_partition - proportions need to sum to 1;
		%end;

	/* confirm whether or not an out of time sample is needed */
	/* the out of time sample - note this assumes that there are a mix of primary and secondary targets in the out of time sample */

	/* it attempts to randomly order observations so that you get a mix of primary and secondary targets in the train and validation
				datasets */
	proc sql;
		create table _temp_ids_randomised as
			select a.*
				,ranuni(&set_seed.) as temp
			from &ds_in. a
				order by

			%if &oot_flag.= True %then
				%do;
					a.&oot_column.,
				%end;

			calculated temp;
	quit;

	/* while I normally go for sql I want to avoid the undocumented monotonic function as per warnings on various blogs */
	data _temp_partition;
		set _temp_ids_randomised nobs = num_rows;
		length partition $ 5;

		if _n_ <= round((&train_pro. * num_rows),1) then
			partition = "TRAIN";
			/* TODO: investigate if adding 1 to the round fixes this problem */
		else if round((&train_pro. * num_rows),1) < _n_ <= round(((&train_pro + &valid_pro ) * num_rows),1) then
			partition = "VALID";
		else partition = "TEST";
	run;

	proc sql;
		create table &ds_out. as
			select a.*
				,b.partition
			from &ds_in. a
				left join _temp_partition b
					on a.&id_variable = b.&id_variable;
	quit;

	/*clean_up */
	%if &local_debug_flag. = False %then
		%do;

			proc datasets lib=work;
				delete _temp_:;
			run;

		%end;
%mend;

	  		
	 	 		

　
