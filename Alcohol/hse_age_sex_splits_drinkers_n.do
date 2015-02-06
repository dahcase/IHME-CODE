
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
	
	
	use "J:\temp\dccasey\Alcohol\AgeSplits\HSE\hse_complete_with_demographics.dta", clear

	drop age
	
	//drop any case missing a strata, psu or pweight
	replace psu=area if psu==.
	drop if strata==. | psu==. | pweight==.
	
	keep region file year psu strata pweight sex age_group gperday
	gen case_id = _n
	
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

	local varsofinterest gperday
	foreach interest of local varsofinterest {
		foreach fff of local thefiles {
			preserve
			keep if file=="`fff'"
			di "FILE IS `fff'"

			//set the survey parameters
			svyset psu [pweight=pweight], strata(strata) singleunit(centered)
			
			//Get the mean consumption
			//remember to limit by miss !=7 &total_drinks !=0
			svy: mean `interest', over(sex age_group region)
			mat b=e(b)'
			mat v=vecdiag((e(V)))' //the transformation from variance into se occurs below
			mat n=e(_N)'
			local labels = e(over_labels)
			
			//get some values  before we drop them
			levelsof year, local(year)
			
			
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
			
			split subpop, parse(" ")
			drop subpop
			rename subpop1 sex
			destring sex, replace
			
			rename subpop2 age_group
			
			egen region = concat(subpop*), punct(" ")
			
			local endyear `year'
			local styear `year'
			
			gen file = "`fff'"
			gen year_start = `styear'
			gen year_end = `endyear'
			drop subpop*
			append using `data'
			save `data', replace
			
			restore
		}
		
		use `data', clear
		//Rename the variables to match what they represent. This is done at the end to prevent any
		//errors from popping up in the actual processing of the code which was written for total_drinks
		rrtert
		replace v_1 = sqrt(v_1) //transform variance into SE
		
		rename b_1 `interest'_prop
		rename v_1 `interest'_se
		rename n_1 `interest'_sample
		save "J:\temp\dccasey\Alcohol\AgeSplits\HSE\hse_`interest'.dta",replace
		clear
		save `data', replace emptyok
		use `info', clear
	}



	cap log close
	
