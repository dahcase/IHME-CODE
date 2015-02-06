//Loop through the combos, mediate and then aggregate as needed
	tempfile riskholder
	save `riskholder',replace
	
	foreach combo of local combos {
		di "`processing this combo: `combo'"
		*use `riskholder', clear
		preserve
		
		//Merge in mediation factors
		merge m:1 acause using "$prefix/WORK/05_risk/other/venn/Mediation/`combo'_test.dta", keep(1 3) nogen
		*save "`workdirectory'/medmid_`combo'_`countryname'_`fileyear'.dta", replace
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
			*replace `var'=.9999 if(`var'==1) // I don't think this is necessary 
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
		
		//add ckd fixes. Diabetes is 100 percent fpg whereas ckd_htn is all sbp. Glomerlo and other at 100% gfr
		//note: rewrite so that this is not a hard fix
		
		foreach var of varlist *paf {
			local hasmetab = strpos("`var'", "metab")
			local hasall = strpos("`var'", "all")
			local has = `hasmetab' +`hasall'
			if `has' >0 {
				replace `var' = 1 if cause=="B.8.3.1" | cause=="B.8.3.2" | cause=="B.8.3.3" | cause=="B.8.3.4"
			}
			else {
				replace `var'=0 if cause=="B.8.3.1" | cause=="B.8.3.2" | cause=="B.8.3.3" | cause=="B.8.3.4"
			}
		}
		
		//now replace the .9999s where they should be 1
		merge 1:1 age sex year cause using "$prefix/WORK/05_risk/other/venn/pafsone/pafsone.dta", nogen keep(1 3) keepusing(risk draw* acause)
		
		//set all risks aggs where there will be a paf of 1 to 0 (the 1 will be inputted later)
		foreach var of varlist mt* mb* {
			replace `var'=0 if risk !=""
		}
		
		
		//change the alls to 1
		replace mtall_paf= 1 if risk!=""
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
		
		drop risk draw* acause //clean up the dataset a bit
		
		
		//Stage 11 / a11 is the switch to recalculate the combined age and sex groups.
		//specifically: age>90 and sex==3. To prepare for that recalculation down the line
		// drop the offending groups
		
		if "`a11'"=="Y" {
			destring age, replace
			drop if age>90
			tostring age, replace
			drop if sex==3
		}
		
		
		
		
		
	