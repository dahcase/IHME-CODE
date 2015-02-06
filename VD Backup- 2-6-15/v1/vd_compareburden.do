clear all

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
local dalynatversion 61 //version of the dalynator
local vdversion `dalynatversion'_testageagg //version of the venn diagram
local codeversion 1 //version of the code
local medversion 1 //version of the mediation

*Derived switches
local sumdirectory "$prefix/WORK/10_gbd/01_dalynator/03_results/`dalynatversion'/summary/" //location of the summary files. Informed by dalynat version
local workdirectory "$prefix/WORK/05_risk/other/venn/Results/v`vdversion'" //location of where to spit the files, informed by vd version
*local sumdirectory "C:/Users/dccasey/Documents/newvd/sum/"
*local workdirectory "C:/Users/dccasey/Documents/newvd/work"
local dimensionsdirect "$prefix/WORK/05_risk/other/venn/dimensions/"
local codedirectory "$prefix/WORK/05_risk/other/venn/Code/" //where to look for the relevant code

use "$prefix/WORK/05_risk/other/venn/Results/v`vdversion'/reshape_CHL_2010.dta", clear
drop iszz2 union_type2
rename union_type risk
keep if risk =="202" | risk=="203" | risk=="204" | risk=="202_203_204"

replace risk = "_all" if risk=="202_203_204"
replace risk = "_env" if risk=="202"
replace risk = "_behav" if risk=="203"
replace risk = "_metab" if risk=="204"

reshape wide value, i(age sex cause iso3 year risk acause) j(measure) string

merge 1:1 iso3 year age sex acause risk using "`sumdirectory'summary_CHL_2010.dta", keep(1 3) keepusing(mean_yll mean_yld mean_death)

