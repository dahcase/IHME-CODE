*Daniel Casey
*12-10-14
*Main Processing script. See outline file in documentation for more details
clear
//Set Stata to desired
clear matrix
clear mata
set maxvar 32000

// Set to run all selected code without pausing
set more off
// Remove previous restores
// Define J drive (data) for cluster (UNIX) and Windows (Windows)
if c(os) == "Unix" {
	global prefix "/home/j"
	set odbcmgr unixodbc
	local useintermediate 0 //set to 1, if you want to save and use intermediate files for a particular run
}
else if c(os) == "Windows" {
	global prefix "J:"
	local useintermediate 1 //set to 1, if you want to save and use intermediate files for a particular run
}

********************************************************************************
*Stage 0: accept the arguments and do initial housekeeping
********************************************************************************

//Accept arguments: `thefile' `countryname' `fileyear' `codeversion' `dalynatversion' `vdversion' `medversion' `instruction'
args sumfile countryname fileyear codeversion dalynatversion vdversion medversion workdirectory instruction
*Check to see if the arguments passed
di "`sumfile'"
di "`countryname'"
di "`fileyear'"
di "`codeversion'"
di "`dalynatversion'"
di "`vdversion'"
di "`medversion'"
di "`workdirectory'"
di "`instruction'"



//Load the instructions
local inslength = strlen("`instruction'")
forvalues iter = 1/`inslength'{
	local a`iter' = substr("`instruction'", `iter', 1)
	di "`a`iter''"
	local ++iter
	
}

//start the log
cap log close
log using "`workdirectory'/logfiles/log_`countryname'_`fileyear'.log", replace
//qui{
//Declare Risk Locals-- There is probably a better way to populate these factors,
*but for now, use the hard coded method
*Environmental Risks
local env air_hap air_ozone air_pm envir_lead envir_radon occ_asthmagens occ_backpain occ_carcino occ_carcino_acid occ_carcino_arsenic occ_carcino_asbestos occ_carcino_benzene occ_carcino_beryllium occ_carcino_cadmium occ_carcino_chromium occ_carcino_diesel occ_carcino_formaldehyde occ_carcino_nickel occ_carcino_pah occ_carcino_silica occ_carcino_smoke occ_hearing occ_injury occ_particulates wash_sanitation wash_water
*Behavioral Risks: Level 4
local beh abuse_csa abuse_ipv activity diet_calcium diet_fiber diet_fish diet_fruit diet_grains diet_milk diet_nuts diet_procmeat diet_pufa diet_redmeat diet_salt diet_ssb diet_transfat diet_veg drugs_alcohol drugs_illicit nutrition_breast nutrition_iron nutrition_underweight nutrition_vitamina nutrition_zinc smoking unsafe_sex
*Metabolic Risks: Level 4
local metab metab_fpg metab_cholesterol metab_bmi metab_gfr metab_bmd metab_sbp

*load the other combinations
local combos all env_metab beh_metab env_beh env metab beh
local env_metab `env' `metab'
local beh_metab `beh' `metab'
local env_beh `env' `beh'
local all `env' `beh' `metab'


//Load up the lowest level causes. Drop any cause that is a parent of another cause
use "$prefix/WORK/00_dimensions/03_causes/causes.dta", clear
keep if cause_version==2 & reporting==1
tempfile causetable
save `causetable', replace

levelsof cause_parent, local(parent)
*levelsof cause, local(child)

foreach cause of local parent {
	drop if cause=="`cause'"
	di "`cause' dropped"
}

levelsof acause, local(llcauses) //get all causes without a child.
tempfile childless
save `childless', replace

clear
//}

********************************************************************************
*Stage 1: open the summary file and pare down to lowest level cause/risk combinations
********************************************************************************
if "`a1'"=="Y"{
//open the file
	di "Load Summary File"
	use "`sumfile'", clear
	
	//get rid of any extra years (e.g the 9999 in 2013 years)
	drop if year==9999 //just to be sure
	keep if year==`fileyear'
	drop if risk=="" //drop causes without risks
	
	//fix the age float nonsense now
	tostring age, replace
	
	//drop non-level 4 causes
	gen kcause =0
	foreach cause of local llcauses {
		qui replace kcause=1 if (acause=="`cause'")
	}
	keep if kcause==1
	
	//rename sex to unsafe_sex to match the actual heirarchy
	replace risk = "unsafe_sex" if risk=="sex"
	
	//Drop non level four risks
	gen krisk=0
	foreach lev4risk of local all {
		qui replace krisk=1 if risk=="`lev4risk'"
	}
	keep if krisk==1
	
	//keep only certain columns
	keep acause iso3 age year sex risk mean_cf_death mean_cf_yld
	
	
	rename mean_cf_death mt
	rename mean_cf_yld mb
	*rename sex gender //do this to prevent conflicts with the sex risk later on
	
	//Set pafs that are not alcohol but less than 0 to 0. Basically, don't let dalynator
	//errors sink the processing.
	replace mt =0 if mt<0 & risk !="drugs_alcohol"
	replace mb = 0 if mt<0 & risk!="drugs_alcohol"
	
	//set pafs of 1 to .9999
	replace mt =.9999 if mt>=1
	replace mb =.9999 if mb>=1
	
	
	reshape wide mt mb, i(age sex iso3 year acause) j(risk) string
	
	//Set missing pafs to 0
	foreach var of varlist mt* mb* {
		qui replace `var'=0 if `var'==.
	}
	
	//add missing risk factors
	foreach var of local all {
		capture confirm variable mt`var'
		if !_rc {
			di "`var' ALREADY EXISTS"
			}
		else {
			
			gen mt`var' = 0
			di "`var' created"
		}
		
		capture confirm variable mb`var'
		if !_rc {
			//di "`var' ALREADY EXISTS"
			}
		else {
			
			gen mb`var' = 0
			//noisily di "`var' created"
		}
	}
	
	if `useintermediate'==1 {
		save "`workdirectory'/risks_`countryname'_`fileyear'.dta", replace
	}
	
}

********************************************************************************
*Stage 2: Apply Mediation and generate the seven parts (in aggregate form)
********************************************************************************
if "`a2'"== "Y"{
	if `useintermediate'==1 {
		use "`workdirectory'/risks_`countryname'_`fileyear'.dta", clear
	}
	//Loop through the combos, mediate and then aggregate as needed
	tempfile riskholder
	save `riskholder',replace
	
	foreach combo of local combos {
		di "`processing this combo: `combo'"
		*use `riskholder', clear
		preserve
		
		//Merge in mediation factors
		merge m:1 acause using "$prefix/WORK/05_risk/other/venn/Mediation/`combo'_test.dta", keep(1 3) nogen
		
		//Fix fpg issue
		capture confirm variable z1`combo'_metab_fpg_cont
		if !_rc {
			rename z1`combo'_metab_fpg_cont z1`combo'_metab_fpg
			}
		else {
			di "No FPG"
		}
		
		//Fix columns for causes that don't have mediation
		qui {
		foreach var of varlist z1`combo'* {
			replace `var'=0 if(`var'==.)
			replace `var'=.9999 if(`var'==1)
		}
		}
		foreach var of varlist z1`combo'* {
			local headLength= strlen("`combo'")+4
			local subVar = substr("`var'", `headLength', .)
			//di "`subVar'"
			replace mt`subVar'= mt`subVar'*(1-`var')
			replace mb`subVar'= mb`subVar'*(1-`var')
			di "`subVar' has been mediated!"
		}
		
		//aggregate-- start by finding the 1-paf
		di "starting agg post mediation!"
		foreach var of local `combo' {
			gen ag_mt`var'=log(1-mt`var')
			gen ag_mb`var'=log(1-mb`var')
		}
		
		//now sum the prepped for ag pafs
		egen ag_mtsum = rowtotal(ag_mt*)
		egen ag_mbsum = rowtotal(ag_mb*)
		
		//exponentiate the value and return to original form
		gen mt`combo'_paf = 1-exp(ag_mtsum)
		gen mb`combo'_paf = 1-exp(ag_mbsum)
		
		
		keep iso3 year age sex acause *_paf
		merge 1:1 iso3 year age sex acause using `riskholder',keep(3) nogen
		save `riskholder', replace

		restore
	}
		use `riskholder', clear
		merge m:1 acause using `causetable', keepusing(cause cause_id cause_parent cause_level) keep(3) nogen
		
		keep iso3 year age sex cause cause_level cause_parent *_paf
		
		//for some reason this process is generating duplicates. Until I figure this out, use this hard fix
		bysort age sex iso3 cause year: gen dup = cond(_N==1,0,_n)
		drop if dup>1
		drop dup
		
		//add ckd fixes. Diabetes is 100 percent fpg whereas ckd_htn is all sbp
		//note: ckd_glomerulo and ckd_other are probably still funky
		
		foreach var of varlist *paf {
			local hasmetab = strpos("`var'", "metab")
			local hasall = strpos("`var'", "all")
			local has = `hasmetab' +`hasall'
			if `has' >0 {
				replace `var' = 1 if cause=="B.8.3.1" | cause=="B.8.3.2"
			}
			else {
				replace `var'=0 if cause=="B.8.3.1" | cause=="B.8.3.2" 
			}
		}
		
		//now replace with the .9999s where they should be 1
		merge 1:1 age sex year cause using "$prefix/WORK/05_risk/other/venn/pafsone/pafsone.dta", nogen keep(1 3) keepusing(risk draw*)
		
		//change the alls to 1
exit		replace mtall_paf=1 if risk!=""
		replace mball_paf= 1 if risk!=""
		
		foreach var of varlist mt* mb*{
			local riskbeh = strpos("`var'", "beh")
			if `riskbeh'> 0 {
			replace `var' = 1 if (risk=="beh")
			}
			local riskmetab = strpos("`var'", "metab")
			if `riskmetab' > 0 {
				replace `var'=1 if risk=="metab"
			}
		}
		drop risk draw* //clean up the dataset a bit
		
	if `useintermediate'==1 {
		save "`workdirectory'/mediation_`countryname'_`fileyear'.dta", replace
	}
}


********************************************************************************
*Stage 3: Calculate the burden for the aggregate causes and ages
********************************************************************************
if "`a3'" == "Y" {
	if `useintermediate'==1 {
		use "`workdirectory'/mediation_`countryname'_`fileyear'.dta", clear
	}
	//The input to this step in a long form datafile that contains the 7 aggregations that I use
	//for both types of outcome by age, sex, cause, year, iso etc. These risk factor pafs have been mediated and aggregated from level 4 to level 2
	// see J:\WORK\05_risk\other\venn\Code\v1\test agg.xlsx for some hand testing. It looks like my results are off by a 1% or 2.
	
	//get the all cause burden estimates
	preserve
	use "`sumfile'", clear
	keep if risk ==""
	keep if year !=9999
	merge m:1 acause using `causetable', keepusing(cause cause_id cause_parent cause_level) keep(3) nogen
	keep age cause sex year iso3 mean_yll mean_yld mean_death acause cause_level cause_parent
	tostring age, replace
	tempfile burden
	save `burden', replace
	restore
	
	
	//Start the collapse chain by bringing the level 4 risk factors to level 3
	*But before doing that, save the level 4 factors seperately
	preserve
	keep if cause_level==4
	tempfile causel4
	save `causel4', replace
	
	//Bring in the burden estimates
	merge m:1 cause sex year age iso3 using `burden', keep(3) nogen
	
	//convert to burden
	foreach var of varlist mt* {
		local newname = substr("`var'", 1, strlen("`var'")-4)
		gen `newname'_yll = `var' * mean_yll
		//rename `var' zzz`var'
	}
	
	foreach var of varlist mb* {
		local newname = substr("`var'", 1, strlen("`var'")-4)
		gen `newname'_yld = `var' * mean_yld
		//rename `var' zzz`var'
	}
	
	//now get rid of the pafs and collapse
	drop *paf
	
	collapse (sum) *yll *yld, by(iso3 year age sex cause_parent)
	rename cause_parent cause // the children are now the parent
	
	//convert back into paf
	foreach var of varlist mt* {
		local newname = substr("`var'", 1, strlen("`var'")-4)
		gen `newname'_paf = `var'/mean_yll
		replace `newname'_paf = 0 if mean_yll ==0
	}
	
	foreach var of varlist mb* {
		local newname = substr("`var'", 1, strlen("`var'")-4)
		gen `newname'_paf = `var'/mean_yld
		replace `newname'_paf = 0 if mean_yld ==0
	}
	
	//do some housekeeping for the upcoming append
	drop *yll *yld
	gen cause_level = 3
	//gen former_level =4
	
	tempfile level4to3
	save `level4to3', replace
	
	restore
	//now bring in the level 4 turned three results and prepare for a looped aggregation
	keep if cause_level==3
	drop cause_parent
	
	append using `level4to3'
	
	
	//now bring in the parent cause
	merge m:1 cause using `causetable', keepusing(cause_parent) keep(3) nogen
	
	
	//save the level 3 causes aside
	preserve
	
	keep if cause_level==3
	tempfile causel3
	save `causel3', replace
	
	restore
	
	
	local causelevels 3 2 1
	
	foreach level of local causelevels {
		keep if cause_level==`level' //keep on the causes we care about
		
		//bring in burden estimates
		merge m:1 age sex year iso3 cause using `burden', keep(3) nogen
		
		foreach var of varlist mt* {
			local newname = substr("`var'", 1, strlen("`var'")-4)
			gen `newname'_yll = `var' * mean_yll
			//rename `var' zzz`var'
		}
	
		foreach var of varlist mb* {
			local newname = substr("`var'", 1, strlen("`var'")-4)
			gen `newname'_yld = `var' * mean_yld
			//rename `var' zzz`var'
		}
		
		//now get rid of the pafs and collapse
		drop *paf
		
		collapse (sum) *yll *yld, by(iso3 year age sex cause_parent)
		rename cause_parent cause // the children are now the parent
		
		foreach var of varlist mt* {
			local newname = substr("`var'", 1, strlen("`var'")-4)
			gen `newname'_paf = `var'/mean_yll
			replace `newname'_paf = 0 if mean_yll ==0
		}
	
		foreach var of varlist mb* {
			local newname = substr("`var'", 1, strlen("`var'")-4)
			gen `newname'_paf = `var'/mean_yld
			replace `newname'_paf = 0 if mean_yld ==0
		}
		
		//do some housekeeping for the upcoming append
		drop *yll *yld
		gen cause_level = `level' -1
		//now bring in the parent cause
		merge m:1 cause using `causetable', keepusing(cause_parent) keep(3) nogen
		
		local savelevel = `level'-1
		
		tempfile causel`savelevel'
		save `causel`savelevel'', replace
		di "save to tempfile `level'"

	}
	
	//Now combine the newly aggregated causes
	append using `causel4'
	append using `causel3'
	append using `causel2'
	append using `causel1'
	//drop cause_parent cause_level
	
	//merge m:1 cause using `causetable', keepusing(acause) keep(3) nogen
	
	bysort age sex iso3 cause year: gen dup = cond(_N==1,0,_n)
	drop dup
	if `useintermediate'==1 {
		save "`workdirectory'/causeheir_`countryname'_`fileyear'.dta", replace
	} 
	
}

********************************************************************************
*Stage 4: Apply the disjoint function to calculate the seven parts of the venn diagram
********************************************************************************
*REWRITE THIS SO THAT the column structure is age, sex, year, iso3, measure, a, b, c, ab, ac, bc, abc etc.
if "`a4'" == "Y" {
	if `useintermediate'==1 {
		use "`workdirectory'/causeheir_`countryname'_`fileyear'.dta", clear
	}
	
	//do some renaming to prevent conflicts later on
	rename age _age
	//rename acause _acause
	rename sex _sex
	rename year _year
	rename iso3 _iso3
	rename cause _cause
	
	
	//For each type of outcome, run the venn diagram disjoint script
	local outcome mt mb //the two types of outcome
	foreach out of local outcome {
		rename `out'env_paf a
		rename `out'beh_paf b
		rename `out'metab_paf c
		rename `out'beh_metab bc
		rename `out'env_beh ab
		rename `out'env_metab ac
		rename `out'all abc
		
		qui do "$prefix/WORK/05_risk/other/venn/Code/v`codeversion'/vd_venncalc_disjointalg.do"
		
		//lots of renaming; zz denotes the disjoint parts
		rename a_zz zz_`out'env
		rename b_zz zz_`out'beh
		rename c_zz zz_`out'metab
		rename bc_zz zz_`out'beh_metab
		rename ab_zz zz_`out'env_beh
		rename ac_zz zz_`out'env_metab 
		rename abc_zz zz_`out'all
		
		rename a `out'env
		rename b `out'beh
		rename c `out'metab
		rename bc `out'beh_metab
		rename ab `out'env_beh
		rename ac `out'env_metab 
		rename abc `out'all
		
	}
		//fix the naming things
		rename _age age
		//rename _acause acause
		rename _sex sex
		rename _year year
		rename _iso3 iso3
		rename _cause cause
	
	if `useintermediate'==1 {
		save "`workdirectory'/abc_`countryname'_`fileyear'.dta", replace
	}
	
}

********************************************************************************
*Stage 5: Convert PAFs to burden 
********************************************************************************
if "`a5'" == "Y" {
	if `useintermediate'==1 {
		use "`workdirectory'/abc_`countryname'_`fileyear'.dta", clear
	}
	
	//merge in burden estimates
	merge m:1 age cause sex year iso3 using `burden', keep(1 3)
	
	//For causes that don't make it in, set missing to 0. For example, in GBR_2013 v49
	//msk_osteoarthritis appears as a rf for 25 year olds, but does not populate a row
	//where risk=="". The following fix is to account for these instances
	replace mean_death=0 if _merge==1
	replace mean_yll=0 if _merge==1
	replace mean_yld=0 if _merge==1
	drop _merge
	
	
	//VERIFY THAT THIS WORKS
	//generate burden estimates for deaths, ylls, ylds
	foreach combo of local combos {
		gen death_`combo' = mt`combo' * mean_death
		gen death_zz_`combo' = zz_mt`combo' *mean_death
		gen yll_`combo'=mt`combo'*mean_yll
		gen yll_zz_`combo'=zz_mt`combo' *mean_yll
		gen yld_`combo'=mb`combo'*mean_yld
		gen yld_zz_`combo' = zz_mb`combo' * mean_yld
	}

	//now generate dalys
	foreach combo of local combos {
		gen daly_`combo'=yll_`combo'+yld_`combo'
		gen daly_zz_`combo'=yll_zz_`combo'+yld_zz_`combo'
	}
	gen dalyoverall=mean_yll+mean_yld
	
	//drop paf columns as they are no longer neccessary
	drop zz* mt* mb* cause_parent cause_level acause
	
	
	if `useintermediate'==1 {
		save "`workdirectory'/burden_`countryname'_`fileyear'.dta", replace
	}
	
}

********************************************************************************
*Stage 6: Reshape the dataset to long form
********************************************************************************
if "`a6'" == "Y" {
	if `useintermediate'==1 {
		use "`workdirectory'/burden_`countryname'_`fileyear'.dta", clear
	}
	
	
	//rename the overall categories
	rename (mean_death mean_yll mean_yld) (deathoverall ylloverall yldoverall)
	reshape long death yll daly yld, i(age sex cause iso3 year) j(union_type) string
	
	rename (death yll yld daly) (valuedeath valueyll valueyld valuedaly)
	reshape long value, i(age sex cause iso3 year union_type) j(measure) string

	//Zero catch if value is ever less than 0, set to 0-- fix rounding errors
	replace value = 0 if value<0
	
	//rename the uniontypes
	gen iszz = strpos(union_type, "zz")
	gen union_type2 = union_type 
	replace union_type2 = substr(union_type, 4, .) if iszz>0
	
	replace union_type2 = "202_203_204" if union_type2=="_all"
	replace union_type2 = "202" if union_type2=="_env"
	replace union_type2 = "203" if union_type2=="_beh"
	replace union_type2 = "204" if union_type2=="_metab"
	replace union_type2 = "202_203" if union_type2=="_env_beh"
	replace union_type2 = "202_204" if union_type2=="_env_metab"
	replace union_type2 = "203_204" if union_type2=="_beh_metab"
	replace union_type2 = "zz_" + union_type2 if iszz>0
	
	replace union_type = union_type2

	*drop iszz
	*drop union_type2
	
	
	if `useintermediate'==1 {
		save "`workdirectory'/reshape_`countryname'_`fileyear'.dta", replace
	}
}
********************************************************************************
*Stage 9: Error Checking (yes I realize that this is out of order)
********************************************************************************
if "`a9'" == "Y" {
	if `useintermediate'==1 {
		use "`workdirectory'/reshape_`countryname'_`fileyear'.dta", clear
	}
	
	tempfile dataset
	save `dataset', replace
	
	//sex comparison : how do my attmepts at recreating sex==3 match up if i just use the dalynator
	
	//first, squirrel away sex == 3
	preserve
	keep if sex==3
	tempfile sex3
	drop iszz union_type2
	save `sex3', replace
	restore
	
	//drop sex 3
	drop if sex==3
	
	collapse (sum) value, by(age cause iso3 year union_type measure)
	gen sex = 4
	append using `sex3'
	
	save "`workdirectory'/errorchecks/sexcompare_`countryname'_`fileyear'.dta", replace
	
	use `dataset', clear
	
	//now check to see if the acause aggregation worked decently. This will compare my burden estimates with
	//what is in the dalynator
	
	*start by dropping types of combinations that the dalynator doesn't work with and do some renaming
	drop if iszz>0
	drop if strlen(union_type)==7 // this will drop the two ways
	drop iszz union_type2
	
	//now shape up the burden/summary file for comparison
	preserve
	use "`sumfile'", clear
	keep if risk =="_all" | risk=="_env" | risk=="_behav" | risk =="_metab"
	keep if year !=9999
	merge m:1 acause using `causetable', keepusing(cause cause_id cause_parent cause_level) keep(3) nogen
	keep age cause sex risk year iso3 mean_yll mean_yld mean_death mean_daly acause cause_level cause_parent
	reshape long mean_, i(iso3 year age sex cause acause risk) j(measure) string
	rename mean burden
	tostring age, replace
	rename risk union_type
	replace union_type = "202_203_204" if union_type =="_all"
	replace union_type = "203" if union_type == "_behav"
	replace union_type = "202" if union_type == "_env"
	replace union_type = "204" if union_type == "_metab"
	drop cause_parent
	tempfile aggtest
	save `aggtest', replace
	
	restore
	
	merge 1:1 iso3 year age sex cause union_type measure using `aggtest'
	
	gen diff = value-burden
	gen perdiff = diff/((value+burden)/2)
	save "`workdirectory'/errorchecks/aggcompare_`countryname'_`fileyear'.dta", replace
	
}
********************************************************************************
*Stage 7: Create output for lifetable
********************************************************************************
if "`a7'" == "Y" {
	if `useintermediate'==1 {
		use "`workdirectory'/reshape_`countryname'_`fileyear'.dta", clear
	}
	preserve //we're going to be doing lots of paring down, so make sure to keep the overall dataset saved
	
		//Drop if the measure != death because lifetables only use deaths
		keep if measure=="death"
		drop measure
		//now drop the values that are not overall of disjoint (zz) parts
		gen zzpart = strpos(union_type, "zz")
		replace zzpart =1 if union_type=="overall"
		keep if zzpart>0
		drop zzpart
		
		//now find the proportion of deaths to risk factors by union type
		/*
		bysort age sex cause iso3 year: egen overall =max(value)
		gen propdeath = value/overall
		replace propdeath =0 if propdeath==.
		*/
		drop if union_type=="overall"
		
		//keep causes that don't have children
		merge m:1 cause using `childless', nogen keep(3) keepusing(acause)
		
		
		collapse (sum) value, by(age sex iso3 year union_type)
		
		tempfile collapsed
		save `collapsed', replace
		
		use `burden', clear
		keep if cause=="Total"
		tempfile allcburden
		save `allcburden', replace
		
		use `collapsed', clear
		
		
		merge m:1 age sex year iso3 using `allcburden', keep(1 3) keepusing(mean_death)
	
		//For causes that don't make it in, set missing to 0. For example, in GBR_2013 v49
		//msk_osteoarthritis appears as a rf for 25 year olds, but does not populate a row
		//where risk=="". The following fix is to account for these instances
		replace mean_death=0 if _merge==1
		drop _merge
		gen propdeath = value/mean_death
		
		*bysort age sex iso3 year: egen prop = total(mean)
		
		*drop mean_death
		
		
		replace union_type = substr(union_type, 4, .)
		
		gen risk="abc"
		replace risk="a" if union_type=="203"
		replace risk="b" if union_type=="202"
		replace risk="c" if union_type=="204"
		replace risk="ab" if union_type=="202_203"
		replace risk="ac" if union_type=="203_204"
		replace risk="bc" if union_type=="202_204"
		
		drop value mean_death
		//rename overall overall_death
		cap drop iszz union_type2
		rename propdeath mean
		
		save "`workdirectory'/decomp/lifetable_`countryname'_`fileyear'.dta", replace
		
		
	restore

}

********************************************************************************
*Stage 8: Create output for website
********************************************************************************
if "`a8'" == "Y" {
	if `useintermediate'==1 {
		use "`workdirectory'/reshape_`countryname'_`fileyear'.dta", clear
	}
	*preserve //we're going to be doing lots of paring down, so make sure to keep the overall dataset saved
		//first drop the union_types we don't need
		*Drop the two and three way unions
		drop if union_type == "202_203"
		drop if union_type == "202_204"
		drop if union_type == "203_204"
		drop if union_type == "202_203_204"
		
		//rename the zz ones we want and drop the rest
		gen zzpart = strpos(union_type, "zz")
		replace union_type = substr(union_type, 4, .) if zzpart>0
		drop iszz union_type2
		
		//Now convert the union_types to numerical form
		merge m:1 union_type using "$prefix/WORK/05_risk/other/venn/dimensions/union_type.dta", keepusing(union_type_id) keep(3) nogen
		
		
		//Now bring in cause id
		merge m:1 cause using `causetable', keepusing(cause_id) keep(3) nogen
		
		//Now bring in measures
		merge m:1 measure using "$prefix/WORK/05_risk/other/venn/dimensions/measure.dta", keepusing(measure_id) keep(3) nogen
		
		//Now bring in locations, which is tricky because subnationals are named in a stupid way
		local subnatck = strlen("`countryname'")
		if `subnatck'>3 {
			gen location_id = substr("`countryname'", 5, .)
			destring location_id, replace
		}
		else {
			rename iso3 local_id
			merge m:1 local_id using "$prefix/WORK/05_risk/other/venn/dimensions/location.dta", keepusing(location_id) keep(3) nogen
			drop local_id
		}
		
		//Fix up age
		rename age age_data
		replace age_data = "0.1" if age_data==".1"
		replace age_data ="0.01" if age_data==".01"
		merge m:1 age_data using "$prefix/WORK/05_risk/other/venn/dimensions/age.dta", keepusing(age_group_id) keep(3) nogen
		
		//Rename year as appropriate
		rename year year_id
		rename sex sex_id
		
		//Now keep only the variables we want
		keep *id value
		
		//Now save
		levelsof location_id, local(location)
		local location `location'
		
		//drop year and location id, since we can get those from the file name
		drop year_id location_id //this means the dimension table creation will require a little bit more work
		
		export delimited "`workdirectory'/vdviztool/data_`location'_`fileyear'.csv", replace

}

cap log close
