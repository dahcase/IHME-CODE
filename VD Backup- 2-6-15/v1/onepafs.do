clear all
set more off
use "j:/temp/stan/paf_all_attrib_01_22_15_formatted_2.dta", clear

gen drawmeanyld = 1
gen drawmeanyll = 1
drop draw_yld* draw_yll*

//hard fix for hypertension
replace risk="metab" if risk=="metab_sbp" & acause=="cvd_htn"

//keep on the level 2 aggregations
keep if risk=="_behav" | risk =="metab" | risk== "_env"
replace risk="beh" if risk=="_behav"
quietly do "$prefix/WORK/05_risk/other/venn/prod/fastcollapse.ado"
preserve
use "J:/WORK/00_dimensions/03_causes/causes.dta", clear
keep if cause_version==2 & reporting==1
tempfile causelist
save `causelist', replace
restore

merge m:1 acause using `causelist', keepusing(acause cause) nogen keep (3)


/*
//expand females by 1 so sex ==3 works as well
expand = 2 if sex==2, gen(dup)
replace sex=3 if dup==1
drop dup
*/
//drop age because all 1s should apply to all age groups------------------------- fix this later
*drop age //we're keeping age because we are recalculating the aggreagated age groups
duplicates drop

/*	
//generate the aggregate age groups	
//99 age
	
fastcollapse draw*, type(sum) by(acause sex year risk cause) append flag(dup)
replace age=99 if dup==1
drop dup
				
//others
gen newage =0
replace newage=91 if age==5 | age== 10
replace drawmeanyll = 1 if drawmeanyll=2
replace drawmeanyld = 1 if drawmeanyld=2
replace newage=92 if age >=15 & age<= 45
replace newage=93 if age >=50 & age<= 65
replace newage=94 if age >=70 & age<=80

fastcollapse draw*, type(sum) by(acause sex year risk newage cause) append flag(dup)
drop if dup==1 & newage==0
replace age=newage if dup==1
drop dup newage

replace drawmeanyll = 1 if drawmeanyll=2
replace drawmeanyld = 1 if drawmeanyld=2
replace drawmeanyll = 1 if drawmeanyll=4
replace drawmeanyld = 1 if drawmeanyld=4
replace drawmeanyll = 1 if drawmeanyll=7
replace drawmeanyld = 1 if drawmeanyld=7
replace drawmeanyll = 1 if drawmeanyll=4
replace drawmeanyld = 1 if drawmeanyld=4
replace drawmeanyll = 1 if drawmeanyll=3
replace drawmeanyld = 1 if drawmeanyld=3
*/

tostring age, replace

save "J:\WORK\05_risk\other\venn\pafsone\pafsone.dta", replace
