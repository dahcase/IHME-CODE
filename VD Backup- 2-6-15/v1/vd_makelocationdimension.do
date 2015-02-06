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
local dalynatversion 59 //version of the dalynator
local vdversion `dalynatversion' //version of the venn diagram
local codeversion 1 //version of the code
local medversion 1 //version of the mediation
local workdirectory "$prefix/WORK/05_risk/other/venn/Results/v`vdversion'" //location of where to spit the files, informed by vd version

local datafiles : dir "`workdirectory'/vdviztool/" files "data*.csv"

foreach file of local datafiles {	
	local flocation = substr("`file'", 11, strlen("`file'")-14)
	local locations : list locations | flocation

}
/*
*location
use "$prefix/WORK/05_risk/other/venn/dimensions/location.dta", clear
gen keeplocal =0
foreach klocation of local locations {
	replace keeplocal =1 if location_id==`klocation'
}
keep if keeplocal==1
drop keeplocal
keep location_id local_id map_id type name
export delim "`workdirectory'/dimensions/location.csv", replace
*/
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
