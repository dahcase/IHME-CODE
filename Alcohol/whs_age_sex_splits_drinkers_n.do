
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
	
*************************************************************************
***							EXTRACT DATASET						   ***
*************************************************************************
/*
// extract data
	svy_extract, ///
	dirlist(J:/DATA/WHO_WHS) use_file(INDIV) skip_subdir(CRUDE) subdirs /// 
	primary_vars(q4010 q4011 q4012 q4013 q4014 q4015 q4016 q4017) ///
	secondary_vars(psu pweight strata q1001 q1002 q1009 q1012 q1013 q1014 q4000 q4001) ///
	merge_file(_ID_) merge_vars(id)
	
// encode variables that had string/numeric inconsistencies
	svy_encode q1001 q1001__s
	svy_encode psu psu__s	
	svy_encode q4010 q4010__s
	svy_encode q1009 q1009__s
	svy_encode q1012 q1012__s
	svy_encode q1013 q1013__s
	svy_encode q1014 q1014__s
	svy_encode q4000 q4000__s
	
// drop files then replace -9999 as null
	drop if file == "J:/DATA/WHO_WHS/TUR/TUR_WHS_2003_INDIVIDUALS_Y2013M04D12.DTA"	
	foreach var of varlist * {
		cap replace `var' = . if `var' == -9999
	}
	
// generate demographics
	gen year_start = regexs(1) if regexm(file,"([0-9][0-9][0-9][0-9])")
	gen year_end = regexs(1) if regexm(file,"`=year_start[_n]'_([0-9][0-9][0-9][0-9])")	
	replace year_end = year_start if mi(year_end)
	destring year_end year_start, replace
	replace file = subinstr(file,"\","/",.)
	replace file = subinstr(file,"/home/j","J:",1)
	gen iso3 = regexs(1) if regexm(file,"/([a-zA-Z][a-zA-Z][a-zA-Z])/") == 1
	gen sex = 1 if inlist(q1001,-9997,2)
	replace sex = 2 if inlist(q1001,-9998,1)
	drop q1001
	rename q1002 age
	
// order variables
	order file iso3 year_start year_end labels psu strata pweight sex age
	sort file iso3 year_start year_end labels psu strata sex age
	
	save "J:\temp\dccasey\Alcohol\AgeSplits\WHS_redo\complete_with_demographics.dta", replace
*/
*************************************************************************
***							TABULATE DATASET						   ***
*************************************************************************
	
	
	
	use "J:\temp\dccasey\Alcohol\AgeSplits\WHS_redo\complete_with_demographics.dta", clear
	cap drop miss
	egen miss = rowmiss(q4011 q4012 q4013 q4014 q4015 q4016 q4017)
	cap drop total_drinks
	egen total_drinks = rowtotal(q4011 q4012 q4013 q4014 q4015 q4016 q4017)
	
	//CONVERT TO GRAMS PER DAY
	replace total_drinks=(total_drinks*10)/7
	
	// generate age_groups-- dothis quietly
	qui {
	//Now begin the processing phase-- starting with defining age_groups
	gen age_group = "80-100" if age>=80
	forvalues i =0(5)75 {
		local j = `i' +5
		replace age_group = "`i'-`=`i'+5'" if age >= `i' & age < `=`i'+5'
	}

	bysort sex iso3 age_group: gen num=_N

	//if a country has age_groups with less than 5 people, change to 10 year age groups
	levelsof iso3 if num<5, local(probisos)
	foreach iso of local probisos {
		forvalues i = 0(10)70 {
			replace age_group = "`i'-`=`i'+10'" if age >= `i' & age < `=`i'+10' &iso3=="`iso'"
		}
	}
	}
	drop age
	
	keep file iso3 year_start year_end psu strata pweight sex total_drinks age_group miss
	gen case_id = _n
	
	//drop any case missing a strata, psu or pweight
	drop if strata==. | psu==. | pweight==.
	
	encode age_group, gen(agegroup_encode)
	
	//find the average grams per day for each file
	levelsof file, local(thefiles)
	foreach fff of local thefiles {
		preserve
		keep if file=="`fff'"
		di "FILE IS `fff'"
		
		//fix the lonely psu problem. 
		//Create Franken strata: the logic according to Grant is below
		// First, we have to combine strata if there are ones with data that only have one psu per strata
		// If there are multiple strata with only one psu, we'll combine them together
		// If there is only one strata that has one psu, we'll combine it with a random other strata
		// We reset the psu so that our psus from different strata don't mix when strata are re-assigned.
		
		//encode psu and strata so we don't get any funkiness
		tostring psu, gen(psu_old)
		drop psu
		encode psu_old, gen(psu)
		
		tostring strata, gen(strata_old)
		drop strata
		encode strata, gen(strata)
		/*
		*set trace on
		//find strata that only have one psu
		local lonelystrat
		levelsof strata, local(thestrata)
		foreach stratum of local thestrata {
			levelsof psu if strata==`stratum', local(psus)
			local numpsus : list sizeof psus
			
			if `numpsus' ==1{
				local lonelystrat `lonelystrat' `stratum'
			}
		}
		
		//now that we have the lonely strata, assign those psus to the same strata
		local numlone : list sizeof lonelystrat
		*tostring psu, gen(txtpsu)
		if `numlone'>1 {
			di "Creating Frankenstrata"
			local iter = -1
			foreach lstrat of local lonelystrat {
				//alter psu so that it won't effect the strata merge
				//use a negative iterator to change the psu-- it won't hurt anything because
				//there is only one psu in the strata so changing the psu using the strata as an if
				//will not alter the structure
				replace psu = `iter' if strata==`lstrat'
				local iter = `iter'-1
				replace strata=-1 if strata== `lstrat' //set all the lonely strata to the same value
			}
		}
		
		else if `numlone'==1  {
			di "Randomly assigning lost strata (`lonelystrat')"
			local estrata : list thestrata - lonelystrat
			*di "`thestrata' ; `lonelystrat'; `estrata'"
			
			local numelig : list sizeof estrata
			tokenize `estrata'			
			local randomselect = 1+int((`numelig'+2)*runiform())			
			replace strata = ``randomselect'' if strata==`lonelystrat'
			
			di "Lost strata `lonelystrat' is now assigned to ``randomselect''"
			
			
			
		}
		*/
		*set trace off
		
		//now that the lonelypsu/lonelystrat problem has be dealt with (fingers cross), run subop analysis
		
		//set the survey parameters
		svyset psu [pweight=pweight], strata(strata) singleunit(centered)
		
		
		//Get the mean consumption
		//remember to limit by miss !=7 &total_drinks !=0
		svy: mean total_drinks if(total_drinks !=0 & miss !=7), over(sex agegroup_encode)
		mat b=e(b)'
		mat v=vecdiag((e(V)))' //the transformation from variance into se occurs below
		mat n=e(_N)'
		local labels = e(over_labels)
		*mat l = e(over_labels)
		*mat testy = e(over_namelist)
		
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
		
		//convert from variance to se
		replace v_1 = sqrt(v_1)
		
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
		
		//fix the column names
		rename b_1 gramsperday_mean
		
		//convert from variance to se
		replace v_1 = sqrt(v_1)
		rename v_1 gramsperday_se
		rename n_1 gramsperday_sample
		
		append using `data'
		save `data', replace
		
		restore
	}
	
	use `data', clear
	//Rename the variables to match what they represent. This is done at the end to prevent any
	//errors from popping up in the actual processing of the code which was written for total_drinks

	
	save "J:\temp\dccasey\Alcohol\AgeSplits\WHS_redo\whsgramsperday_2.dta",replace
	
	cap log close
	
