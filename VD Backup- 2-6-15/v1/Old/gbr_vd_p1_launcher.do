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
	local run 1 //1 means run the dimensions creation process as well
}
else if c(os) == "Windows" {
	global prefix "J:"
}

********************************************************************************
*Stage 0: Declare locals to act as switches and that otherwise govern the
*running of the program
********************************************************************************

*Things that need to be set
local dalynatversion 57 //version of the dalynator
local vdversion `dalynatversion'_2GBR //version of the venn diagram
local codeversion 1 //version of the code
local medversion 1 //version of the mediation
//////////Stage #:1234567890
local instruction YYYYYYYYNN //foreach stage, say whether you want to run this part (e.g. a y or n in the appropriate part)
					   //each letter refers to a stage
***NOTE: local run is set in the define jdrive area

*Contraints
local location all //if you want to constrain the run by country(s) replace all with the iso3 codes.
			  //For subnational units, this will have to work in a different way. Instead, supply
			  //the iso of the parent country the three letter code that identifies the subnational
			  //unit. Remove all if you don't want to run all
local years all  //constrain the years that the process runs.

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
*Start logging
cap log close 
log using "`workdirectory'/logfiles/launcher.log", replace

*Get the list of summary files to be processed. Check to see if there are constraints
di "Country runs: `location' and years run: `years'"

if "`location'"=="all" & "`years'"=="all" { //check to see if we are running all of the locations and years
	di "Run everything"
	local sumfiles : dir "`sumdirectory'" files "summary_GBR*.dta"
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
local thejobs
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
		!/usr/local/bin/SGE/bin/lx24-amd64/qsub -N `job' -pe multi_slot 4 -l mem_free=4G "`codedirectory'stata_shell.sh" "`codedirectory'v`codeversion'/vd_p2_createvenn_test.do" "`thefile' `countryname' `fileyear' `codeversion' `dalynatversion' `vdversion' `medversion' `workdirectory' `instruction'"
		local thejobs `thejobs'`job',
		sleep 100
	}
	else if c(os) == "Windows" {
		do "`codedirectory'v`codeversion'/vd_p2_createvenn_test.do" `thefile' `countryname' `fileyear' `codeversion' `dalynatversion' `vdversion' `medversion' `workdirectory' `instruction'
	}	
}

//run the dimensions table part
if `run'==1 {
	di "MAKE DIMENSIONS"
	di "`workdirectory'"
	di "`thejobs'"
	!/usr/local/bin/SGE/bin/lx24-amd64/qsub -N "gatherdimensions" -pe multi_slot 4 -l mem_free=4G -hold_jid "`thejobs'" "`codedirectory'stata_shell.sh" "`codedirectory'v`codeversion'/vd_p3_makedimensions.do" `workdirectory'

}


qui cap log close
