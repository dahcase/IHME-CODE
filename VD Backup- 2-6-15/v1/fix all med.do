clear all
set more off
** Set directories
	if c(os) == "Windows" {
		global j "J:"
		*set mem 1g
	}
	if c(os) == "Unix" {
		global j "/home/j"
		*set mem 2g
		set odbcmgr unixodbc
	}

	
local folder "$j/WORK/05_risk/other/venn/Mediation/"
use "$j/WORK/05_risk/temp/mediation/all mediations.dta", clear

//drop the old activity-fpg relationship
drop if (acause=="cvd_ihd" | acause=="cvd_stroke_isch") & risk=="activity" &med_=="metab_fpg"

//bring in the new fpg relationship
append using "J:\temp\dccasey\fixmed\fpgmed.dta"
//the preceding file was created using: J:\temp\dccasey\fixmed\add activity_fpg mediation
//fix air pollution issues
replace risk = risk_orig
drop if risk=="air_hap"

expand 2 if risk=="air_pm", gen(dup)
replace risk="air_hap" if dup==1
gen risk_orig_backup=risk_orig
replace risk_orig=risk

order acause risk med_
sort acause risk med_

//drop instances where a risk is mediating itself
drop if risk == med_ 

//remove the mediation between nutrition underweight and nutrition zinc

drop if risk=="nutrition_zinc" & med_=="nutrition_underweight"

save "$j/WORK/05_risk/temp/mediation/all mediations_adj.dta", replace
