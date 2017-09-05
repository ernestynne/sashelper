/*********************************************************************************************************
DESCRIPTION: feature seclection via variable clustering

INPUT: 
ds_in              = input table
max_eigen          = maximum second eigenvalue cut off for whether or not to split the cluster
max_cluster        = maximum number of clusters / variables to keep
maintain_hierarchy = enforces hierarchy of the clusters {True | False} this prevents variables
                     being reassigned to different clusters which will speed up processing
local_debug_flag   = flag for debugging when set to true all _temp_ datasets are retained

OUTPUT:
var_out = macro variable containing a space separated list of all the best variables for each cluster
for variable selection

DEPENDENCIES: 

NOTES: 
var_out requires a triple ampersand to resolve the list of the best variables


AUTHOR: 
E Walsh

HISTORY:
23 Aug 2017 EW added more arguments to give more control over the clustering 
15 Jul 2016 EW v1
*********************************************************************************************************/
%macro get_varclus (ds_in = , max_eigen = 0.8, max_cluster = 20, maintain_hierarchy = True,
			var_out = varclus_best_var,	local_debug_flag = False);
	%put ********************************************************************;
	%put --------------------------------------------------------------------;
	%put ---------------------------sashelper--------------------------------;
	%put ..........start_run_at: %sysfunc(datetime(), datetime20.);
	%put --------------------------------------------------------------------;
	%put ----------------------get_varclus: Inputs---------------------------;
	%put .................ds_in: &ds_in.;
	%put .............max_eigen: &max_eigen.;
	%put ...........max_cluster: &max_cluster.;
	%put ....maintain_hierarchy: &maintain_hierarchy.;
	%put ...............var_out: &var_out;
	%put ......local_debug_flag: &local_debug_flag;
	%put --------------------------------------------------------------------;
	%put ********************************************************************;

	proc varclus data= &ds_in. maxeigen = &max_eigen. maxclusters = &max_cluster. short 
		%if &maintain_hierarchy = True %then hi;
		;
		var _numeric_;
		ods output rsquare = output_varclus_rsq (rename = (NumberOfClusters = num_cluster));
	run;

	/* find how many clusters there are so that we can grab the final iteration */
	proc sql noprint;
		select max(num_cluster) into:num_clusters
			from output_varclus_rsq;
	quit;

	proc sql;
		create table _temp_final_rsq as
			select *
				from output_varclus_rsq
					where num_cluster = &num_clusters;
	quit;

	/* the table only lists the cluster number for the first variable in the cluster - populate
	the rest of them */
	data _temp_fill_in_clusters (rename = (rsquareratio = r_square_ratio));
		set _temp_final_rsq;
		retain cluster_imp;

		/* make note of the last known cluster label */
		if not missing(cluster) then
			cluster_imp = cluster;

		/* if a missing cluster label is encountered then use the last known label */
		if missing(cluster) then
			cluster = cluster_imp;
	run;

	proc sort data=_temp_fill_in_clusters;
		by cluster r_square_ratio;
	run;

	/* identify the best variable from each cluster */
	title 'Variable cluster - best variables in cluster order';
	proc sql;
		select variable into: &var_out. separated by ' '
			from _temp_fill_in_clusters
				group by cluster
					having r_square_ratio = min(r_square_ratio);
	quit;
	title;

	%put NOTE: In get_varclus - &var_out.: &&&var_out.;

	/*clean_up */
	%if &local_debug_flag. = False %then
		%do;

			proc datasets lib=work;
				delete _temp_:;
			run;

		%end;
%mend;

