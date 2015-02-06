clear all
set more off
use "J:/temp/stan/paf_all_attrib_12_19_14_formatted.dta", clear

egen drawmeanyld = rowmean(draw_yld*)
egen drawmeanyll = rowmean(draw_yll*)
drop draw_yld* draw_yll*

//hard fix for hypertension
replace risk="metab" if risk=="metab_sbp" & acause=="cvd_htn"

//keep on the level 2 aggregations
keep if risk=="_behav" | risk =="metab" | risk== "_env"
replace risk="beh" if risk=="_behav"

preserve
use "J:/WORK/00_dimensions/03_causes/causes.dta", clear
keep if cause_version==2 & reporting==1
tempfile causelist
save `causelist', replace
restore

merge m:1 acause using `causelist', keepusing(cause) nogen keep (3)

tostring age, replace

//expand females by 1 so sex ==3 works as well
expand = 2 if sex==2, gen(dup)
replace sex=3 if dup==1

save "J:\WORK\05_risk\other\venn\pafsone\pafsone.dta", replace
