*Daniel Casey
*12-10-14
*Launcher script for the Venn Diagram/Mediation Creator
// Set preferences for STATA
// Clear memory and set memory and variable limits
clear

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

args workdirectory
di "`workdirectory'"


cap log close 
log using "`workdirectory'/logfiles/gatherdimensions.log", replace

local datafiles : dir "`workdirectory'/dimensions/hold/" files "dimen*.csv"

foreach file of local datafiles {
	import delim "`workdirectory'/dimensions/hold/`file'", clear
	
	local fyear = substr("`file'", 7, 4)
	local flocation = substr("`file'", 12, strlen("`file'")-15)
	
	noi di "`flocation'_`fyear'"
	
	qui {
	levelsof sex_id, local(fsexes)
	levelsof union_type, local(funions)
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
keep location_id local_id map_id type name
foreach var of varlist local_id map_id type name {
	replace `var' = "" if `var'=="\t"
}
export delim "`workdirectory'/dimensions/location.csv", replace

*union_type
use "$prefix/WORK/05_risk/other/venn/dimensions/union_type.dta", clear
gen keepunion=0
foreach kunion of local union {
	replace keepunion=1 if union_type == "`kunion'"
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

*risk
//Until this works for more than the level 2 risk groups, just save the ones we need
use "$prefix/WORK/05_risk/other/venn/dimensions/risk.dta", replace
keep if inlist(risk_id, 169, 202, 203, 204)
export delim "`workdirectory'/dimensions/risk.csv", replace

qui cap log close
