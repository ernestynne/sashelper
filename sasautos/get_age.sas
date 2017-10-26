/*********************************************************************************************************

DESCRIPTION: calculate the age of a person in either a data step or sql

INPUT:

start date = date of birth
end date   = time point at which you want to calculate age

OUTPUT:

age in years

AUTHOR: E Walsh

DEPENDENCIES:

NOTES:

output needs to be assigned to a variable in a sql script or data step

HISTORY:

01 Apr 2016 EW v1

*********************************************************************************************************/

%macro get_age(beg_date, end_date);

/* note the absence of the semicolon so that this can be used within proc sql */

floor( (intck('month', &beg_date, &end_date) - (day(&end_date) < min (day(&beg_date),

day (intnx ('month', &end_date, 1) - 1) ) ) ) /12 )

%mend;

