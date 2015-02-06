********************************************************************************
*Stage 5: Convert PAFs to burden //it might be worth rewrting the next step to work in long form
********************************************************************************
if "`a5'" == "Y" {
	if `useintermediate'==1 {
		use "`workdirectory'/abc_`countryname'_`fileyear'.dta", clear
	}
	
	//reshape dataset back to long form
	reshape long mt mb zz_mt zz_mb, i(age cause iso3 sex year) j(union) string
	
	//yy shows the unions
	rename mb yy_mb
	rename mt yy_mt
	reshape long yy_ zz_, i(age cause iso3 sex year union) j(type) string
	
	gen death = mean_death*yy_
	gen 
	
	
	//reshape the summary file so the burden estimates work
	preserve
	use "`sumfile'", clear
	keep if risk ==""
	merge m:1 acause using `causetable', keepusing(cause) keep(3) nogen
	keep age cause sex year iso3 mean_yll mean_yld mean_death acause
	tostring age, replace
	tempfile burden
	save `burden', replace
	restore
	
	//merge in burden estimates
	merge m:1 age cause sex year iso3 using `burden', keep(1 3)
	
	
	asdfasd
	//For causes that don't make it in, set missing to 0. For example, in GBR_2013 v49
	//msk_osteoarthritis appears as a rf for 25 year olds, but does not populate a row
	//where risk=="". The following fix is to account for these instances
	replace mean_death=0 if _merge==1
	replace mean_yll=0 if _merge==1
	replace mean_yld=0 if _merge==1
	drop _merge
	
	if `useintermediate'==1 {
		save "`workdirectory'/burden_`countryname'_`fileyear'.dta", replace
		di "Use is on for stage 5"
	}
	
}
