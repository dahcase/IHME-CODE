/*
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
