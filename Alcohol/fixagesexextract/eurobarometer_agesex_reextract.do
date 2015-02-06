
// prep stata
	clear all
	tempfile data
	save `data', emptyok replace
	set more off
	set maxvar 32000
	set matsize 11000
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
	
//load data into one joint dataset
	local datafiles : dir "J:\temp\dccasey\Alcohol\AgeSplits\Eurobarometer/" files "complete*.dta"

	foreach df of local datafiles {
		append using "J:\temp\dccasey\Alcohol\AgeSplits\Eurobarometer/`df'"
	}

	di _N
	
	// generate age_group
	//Now begin the processing phase-- starting with defining age_groups
	gen age_group = "80-100" if age>=80
	forvalues i =0(5)75 {
		local j = `i' +5
		replace age_group = "`i'-`=`i'+5'" if age >= `i' & age < `=`i'+5'
	}
	encode age_group, gen(age_group_enc)
	encode iso3, gen(iso3_enc)
	drop age
	//drop any case missing a strata, psu or pweight
	drop if strata==. | psu==. | pweight==.

	//generate the list we will iterate over
	levelsof file, local(thefiles)
	local varsofinterest gperday
	foreach interest of local varsofinterest {
		foreach fff of local thefiles {
			preserve
			keep if file=="`fff'"
			di "FILE IS `fff'"

			//set the survey parameters
			svyset psu [pweight=pweight], singleunit(centered) //strata is omitted because it is not provided by the survey-- should be fine?
			
			//Get the mean consumption of drinkers
			svy: mean `interest' if (gperday>0 & gperday!=.), over(sex age_group_enc iso3_enc)
			mat b=e(b)'
			mat v=vecdiag((e(V)))' //the transformation from variance into se occurs below
			mat n=e(_N)'
			local labels = e(over_labels)
			
			//get some values  before we drop them
			levelsof year_start, local(syear)
			levelsof year_end, local(eyear)
			
			
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
			
			rename subpop3 iso3
			
			local endyear `eyear'
			local styear `syear'
			
			gen file = "`fff'"
			gen year_start = `styear'
			gen year_end = `endyear'
			cap drop subpop*
			append using `data'
			save `data', replace
			
			restore
		}
		
		use `data', clear
		//Rename the variables to match what they represent. This is done at the end to prevent any
		//errors from popping up in the actual processing of the code which was written for total_drinks
		replace v_1 = sqrt(v_1) //transform variance into SE
		
		rename b_1 `interest'_mean
		rename v_1 `interest'_se
		rename n_1 `interest'_sample
		save "J:\temp\dccasey\Alcohol\AgeSplits\Eurobarometer/eurobaro_re_`interest'.dta",replace
		clear
		save `data', replace emptyok
		use `info', clear
		local last `interest'
	}
	use "J:\temp\dccasey\Alcohol\AgeSplits\Eurobarometer/eurobaro_re_`last'.dta", clear


	cap log close
	
