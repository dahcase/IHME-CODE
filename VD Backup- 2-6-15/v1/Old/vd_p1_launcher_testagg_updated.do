*Daniel Casey
*12-10-14
*Launcher script for the Venn Diagram/Mediation Creator
// Set preferences for STATA
// Clear memory and set memory and variable limits
clear all
macro drop _all

// Set to run all selected code without pausing
set more off
// Remove previous restores
cap restore, not
// Define J drive (data) for cluster (UNIX) and Windows (Windows)
if c(os) == "Unix" {
	global prefix "/home/j"
	set odbcmgr unixodbc
}
else if c(os) == "Windows" {
	global prefix "J:"
}

********************************************************************************
*Stage 0: Declare locals to act as switches and that otherwise govern the
*running of the program
********************************************************************************
local run 2 //1 denotes run the main script, 2 means run the gather


*Things that need to be set
local dalynatversion 56 //version of the dalynator
local vdversion `dalynatversion' //version of the venn diagram
local codeversion 1 //version of the code
local medversion 1 //version of the mediation
//////////Stage #:123456789
local instruction YYYYYYYYN //foreach stage, say whether you want to run this part (e.g. a y or n in the appropriate part)
					   //each letter refers to a stage

*Contraints
local location all //if you want to constrain the run by country(s) replace all with the iso3 codes.
			  //For subnational units, this will have to work in a different way. Instead, supply
			  //the iso of the parent country the three letter code that identifies the subnational
			  //unit. Remove all if you don't want to run all
local years all //constrain the years that the process runs.

*Derived switches
local sumdirectory "$prefix/WORK/10_gbd/01_dalynator/03_results/`dalynatversion'/summary/" //location of the summary files. Informed by dalynat version
local workdirectory "$prefix/WORK/05_risk/other/venn/Results/v`vdversion'" //location of where to spit the files, informed by vd version
*local sumdirectory "C:\Users\dccasey\Documents\newvd\sum/"
*local workdirectory "C:\Users\dccasey\Documents\newvd\work"
local dimensionsdirect "$prefix/WORK/05_risk/other/venn/dimensions/"
local codedirectory "$prefix/WORK/05_risk/other/venn/Code/" //where to look for the relevant code

*Generate the file directory network
cap mkdir "`workdirectory'/"
cap mkdir "`workdirectory'/errorchecks"
cap mkdir "`workdirectory'/decomp"
cap mkdir "`workdirectory'/vdviztool"
cap mkdir "`workdirectory'/dimensions"
cap mkdir "`workdirectory'/logfiles/"

********************************************************************************
*Stage 1: Launch the jobs to be processed. In this case, launch a job by country-year
*summary file provided by the dalynator output
********************************************************************************
if `run'== 1 {
*Start logging
cap log close 
log using "`workdirectory'/logfiles/launcher.log", replace

*Get the list of summary files to be processed. Check to see if there are constraints
di "Country runs: `location' and years run: `years'"

if "`location'"=="all" & "`years'"=="all" { //check to see if we are running all of the locations and years
	di "Run everything"
	local sumfiles : dir "`sumdirectory'" files "*.dta"
	*di "Process these files" `sumfiles'
}
else {
	local sumfiles
	foreach unit of local location {
		foreach year of local years {
		local holdsum "summary_`unit'_`year'.dta"
		local sumfiles `sumfiles' `holdsum'
		}
	}
	*di "Process these files `sumfiles'"
}
//now launch the jobs.
local jobnum 0
foreach file of local sumfiles {
	local ++jobnum
	
	*Get the country and year to make job naming useful
	*di "`file'"
	local countryname = substr("`file'", 9, strlen("`file'")-17)
	*di " the country name is `countryname'"
	local fileyear = substr("`file'", strlen("`file'")-7,4)
	local job "`countryname'_`fileyear'"
	di "JOB name: `job'"
	di "JOB num: `jobnum'"
	//Pass through the following arguments: summary file and path, country, file year, code version, dalynator version, venn diagram version
	local thefile "`sumdirectory'`file'"
	*!/usr/local/bin/SGE/bin/lx24-amd64/qsub -N `job' -pe multi_slot 4 -l mem_free=4G "`codedirectory'stata_shell.sh" "`codedirectory'v`codeversion'/vd_p2_createvenn.do" "`thefile' `countryname' `fileyear' `codeversion' `dalynatversion' `vdversion' `instruction'"
	
	if c(os) == "Unix" {
		!/usr/local/bin/SGE/bin/lx24-amd64/qsub -N `job' -pe multi_slot 4 -l mem_free=4G "`codedirectory'stata_shell.sh" "`codedirectory'v`codeversion'/vd_p2_createvenn_testagg_updated.do" "`thefile' `countryname' `fileyear' `codeversion' `dalynatversion' `vdversion' `medversion' `workdirectory' `instruction'"
		sleep 100
	}
	else if c(os) == "Windows" {
		do "`codedirectory'v`codeversion'/vd_p2_createvenn_testagg_updated.do" `thefile' `countryname' `fileyear' `codeversion' `dalynatversion' `vdversion' `medversion' `workdirectory' `instruction'
	}
	
	
}
*di "I have just launched `jobnum' jobs"
}

//run the dimensions table part
if `run'==2 {
	cap log close 
	log using "`workdirectory'/logfiles/gatherdimensions.log", replace

	local datafiles : dir "`workdirectory'/vdviztool/" files "data*.csv"
	
	foreach file of local datafiles {
		import delim "`workdirectory'/vdviztool/`file'", clear
		
		local flocation = substr("`file'", 6, strlen("`file'") - 14)
		local fyear = substr("`file'", strlen("`file'")-7, 4)
		
		noi di "`flocation'_`fyear'"
		
		qui {
		levelsof sex_id, local(fsexes)
		levelsof union_type_id, local(funions)
		levelsof measure_id, local(fmeasures)
		levelsof age_group_id, local(fages)
		levelsof cause_id, local(fcauses)
		}
		
		local sex : list sex | fsexes
		local measure: list measure | fmeasures
		local age : list age | fages
		local cause : list cause | fcauses
		local locations : list locations | flocation
		local year : list year | fyear
		local union : list union | funions
		
	}
	//Now that we have the dimensions, loop through the full size dimension tables and pare them down as necessary
	
	*start with causes, which is in a differnet spot
	use "$prefix/WORK/00_dimensions/03_causes/causes.dta", clear
	keep if cause_version==2 & reporting==1
	gen keepcause =0
	foreach kcause of local cause {
		replace keepcause =1 if cause_id == `kcause'
	}
	keep if keepcause==1
	drop keepcause
	export delimited "`workdirectory'/dimensions/cause.csv", replace
	
	*measure
	use "$prefix/WORK/05_risk/other/venn/dimensions/measure.dta", clear
	gen keepmeasure = 0
	foreach kmeasure of local measure {
		replace keepmeasure =1 if measure_id ==`kmeasure'
	}
	keep if keepmeasure==1
	drop keepmeasure
	export delim "`workdirectory'/dimensions/measure.csv", replace
	
	*sex
	use "$prefix/WORK/05_risk/other/venn/dimensions/sex.dta", clear
	gen keepsex =0
	foreach ksex of local sex {
		replace keepsex=1 if sex_id==`ksex'
	}
	keep if keepsex==1
	drop keepsex
	export delim "`workdirectory'/dimensions/sex.csv", replace
	
	*age
	use "$prefix/WORK/05_risk/other/venn/dimensions/age.dta", clear
	gen keepage=0
	foreach kage of local age {
		replace keepage=1 if age_group_id ==`kage'
	}
	keep if keepage ==1
	drop keepage
	export delimited "`workdirectory'/dimensions/age.csv", replace
	
	*location
	use "$prefix/WORK/05_risk/other/venn/dimensions/location.dta", clear
	gen keeplocal =0
	foreach klocation of local locations {
		replace keeplocal =1 if location_id==`klocation'
	}
	keep if keeplocal==1
	drop keeplocal
	export delim "`workdirectory'/dimensions/location.csv", replace
	
	*union_type
	use "$prefix/WORK/05_risk/other/venn/dimensions/union_type.dta", clear
	gen keepunion=0
	foreach kunion of local union {
		replace keepunion=1 if union_type_id == `kunion'
	}
	keep if keepunion==1
	drop keepunion
	export delim "`workdirectory'/dimensions/union_type.csv", replace
	
	*year
	use "$prefix/WORK/05_risk/other/venn/dimensions/year.dta", replace
	gen keepyear=0
	foreach kyear of local year {
		replace keepyear=1 if year_id ==`kyear'
	}
	keep if keepyear==1
	drop keepyear
	export delim "`workdirectory'/dimensions/year.csv", replace
}


qui cap log close
