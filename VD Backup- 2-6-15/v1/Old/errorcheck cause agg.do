clear all
set more off
/*
use "J:\WORK\10_gbd\01_dalynator\03_results\54\summary\summary_USA_2010.dta" 

keep if year ==2010
keep if risk == "_all" | risk == "_env" | risk == "_behav" | risk == "_metab"
keep age sex year acause iso3 risk mean_death mean_yll mean_yld

preserve
drop if risk == "_all"
collapse (sum) mean*, by(age sex year iso3 acause)
gen risk ="all2"

tempfile newall
save `newall', replace

restore
preserve
drop if risk !="_all"
tempfile oldall
save `oldall', replace
restore
clear
append using `newall'
append using `oldall'

reshape wide mean*, i(iso3 year age sex acause) j(risk) string

gen difdeath =mean_death_all - mean_deathall2
gen difyld = mean_yld_all - mean_yldall2
gen difyll = mean_yll_all - mean_yllall2

*/
/*
use "J:\WORK\05_risk\other\venn\Results\v54_3\causeheir_USA_2013.dta", clear
levelsof cause, local(thecauses)
clear

use "J:/WORK/00_dimensions/03_causes/causes.dta", clear
keep if cause_version==2 & reporting==1

gen kcause = 0
foreach thecause of local thecauses {
	replace kcause=1 if cause =="`thecause'"
}

keep cause acause cause_level cause_parent kcause

gen numcause =1

collapse (sum) kcause numcause, by(cause_parent)
*/

use "J:\WORK\05_risk\other\venn\Results\v54_3\errorchecks\aggcompare_USA_2013.dta", clear

levelsof acause, local(thecauses)
foreach cause of the causes {
	preserve
	
	keep if acause="`cause'"
	
	sum value burden
	
	
	restore
}


