
// prep stata
	clear all
	tempfile data
	save `data', emptyok replace
	set more off
	set maxvar 32000
	pause on
	if c(os) == "Unix" {
		global prefix "/home/j"
		set odbcmgr unixodbc
	}
	else if c(os) == "Windows" {
		global prefix "J:"
	}
	global dsn = "epi"
	cap log close
	log using "J:\temp\dccasey\Alcohol\AgeSplits\WHS_redo\whs_process.log", replace
// load survey subroutines
	run "J:\WORK\04_epi\01_database\01_code\02_central\01_code\prod\adofiles\svy_extract.ado"
	run "J:\WORK\04_epi\01_database\01_code\02_central\01_code\prod\adofiles\svy_encode.ado"
	run "J:\WORK\04_epi\01_database\01_code\02_central\01_code\dev\svy_subpop.ado"
	run "J:\WORK\04_epi\01_database\01_code\02_central\01_code\prod\adofiles\svy_svyset.ado"
	
	
	// generate age_groups-- dothis quietly
	qui {
	//Now begin the processing phase-- starting with defining age_groups
	gen age_group = "80-100" if age>=80
	forvalues i =0(5)75 {
		local j = `i' +5
		replace age_group = "`i'-`=`i'+5'" if age >= `i' & age < `=`i'+5'
	}
	drop age
	
	//drop any case missing a strata, psu or pweight
	drop if strata==. | psu==. | pweight==.
	
	encode age_group, gen(agegroup_encode)
	
	//find the average grams per day for each file

	levelsof file, local(thefiles)
	//encode psu and strata so we don't get any funkiness
	tostring psu, gen(psu_old)
	drop psu
	encode psu_old, gen(psu)
		
	tostring strata, gen(strata_old)
	drop strata
	encode strata, gen(strata)
	tempfile info
	save `info', replace
	local varsofinterest ever_drinker lifetime_abstainer ever_binge current_drinker_wk
	foreach interest of local varsofinterest {
		foreach fff of local thefiles {

			preserve
			keep if file=="`fff'"
			di "FILE IS `fff'"

			//set the survey parameters
			svyset psu [pweight=pweight], strata(strata) singleunit(centered)
			
			//Get the mean consumption
			//remember to limit by miss !=7 &total_drinks !=0
			svy: mean `interest', over(sex agegroup_encode)
			mat b=e(b)'
			mat v=vecdiag((e(V)))' //the transformation from variance into se occurs below
			mat n=e(_N)'
			local labels = e(over_labels)
			
			//get some values  before we drop them
			levelsof year_start, local(styear)
			levelsof year_end, local (endyear)
			levelsof iso3, local(theiso)
			
			
			clear
			svmat b, names(b_)
			svmat v, names(v_)
			svmat n, names(n_)
			
			gen subpop=""
			gen case = _n
			local iter 1
			foreach lbl of local labels {
				replace subpop="`lbl'" if case==`iter'
				local iter = `iter' +1
			}
			
			
			//Fix up the datasheet a little bit before moving onto the next file
			gen sex = substr(subpop, 1, 1)
			destring sex, replace
			
			gen age_group = substr(subpop, 3,.)
			drop subpop
			

			local iso `theiso'
			local endyear `endyear'
			local styear `styear'
			
			gen year_start = `styear'
			gen year_end = `endyear'
			gen iso3 = "`iso'"
			
			append using `data'
			save `data', replace
			
			restore
		}
		
		use `data', clear
		//Rename the variables to match what they represent. This is done at the end to prevent any
		//errors from popping up in the actual processing of the code which was written for total_drinks
		
		replace v_1 = sqrt(v_1) //transform variance into SE
		
		rename b_1 `interest'_prop
		rename v_1 `interest'_se
		rename n_1 `interest'_sample
		save "J:\temp\dccasey\Alcohol\catsofdrinkes\whs_`interest'.dta",replace
		clear
		save `data', replace emptyok
		use `info', clear
	}
		cap log close
	
