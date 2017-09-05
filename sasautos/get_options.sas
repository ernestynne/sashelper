/*********************************************************************************************************
DESCRIPTION: Specify system options for the SAS session

INPUT:
local_optimise_flag = flag that can help you optimise the sas code {True | False} 
local_debug_flag    = flag that can help you debug scripts by resolving the macros {True | False}

OUTPUT:
system options triggered see details within the script

AUTHOR: E Walsh

DEPENDENCIES:
NA

NOTES: 
NA

HISTORY: 
25 Jul 2017 EW v1
*********************************************************************************************************/
%macro get_options(local_optimise_flag=, local_debug_flag=);
	%put ********************************************************************;
	%put --------------------------------------------------------------------;
	%put ---------------------------sashelper--------------------------------;
	%put ..........start_run_at: %sysfunc(datetime(), datetime20.);
	%put --------------------------------------------------------------------;
	%put --------------------get_options: Inputs-----------------------------;
	%put ...local_optimise_flag: &local_optimise_flag;
	%put ......local_debug_flag: &local_debug_flag;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;
	%if &local_optimise_flag. = True %then
		%do;
			/* generate performance stats on cpu usage, memory, IO etc */
			options fullstimer;

			/* display information - handy to find out more info about indexes being used */
			options msglevel = i;
		%end;
	%else %if &local_optimise_flag. = False %then
		%do;
			/* switch back to not writing a complete list of resources to the log */
			options nofullstimer;

			/* switch back to the default notes rather than information */
			options msglevel = n;
		%end;
	%else
		%do;
	%put ERROR: In get_options - local_optimise_flag. must be one of {True | False};
		%end;

	%if &local_debug_flag. = True %then
		%do;
			/* print macro code with resolved macro variables */
			options mlogic mprint;
		%end;
	%else  %if &local_debug_flag. = False %then
		%do;
			/*switch back to defaults */
			options nomlogic nomprint;
		%end;
	%else
		%do;
	%put ERROR: In get_options - local_debug_flag. must be one of {True | False};
		%end;
%mend;