
// prep stata
	clear all
	
	//create a blank tempfile for later
	tempfile master
	save `master', replace emptyok
	
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
	//set locals
	local workdir "J:/temp/dccasey/Alcohol/catsofdrinkes/"
	
	log using "`workdir'\whs_alc_prev_extract.log", replace
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
	secondary_vars(psu pweight strata q1001 q1002 q1009 q1012 q1013 q1014) ///
	merge_file(_ID_) merge_vars(id)
	
// encode variables that had string/numeric inconsistencies
	svy_encode q1001 q1001__s
	svy_encode psu psu__s	
	svy_encode q4010 q4010__s
	svy_encode q1009 q1009__s
	svy_encode q1012 q1012__s
	svy_encode q1013 q1013__s
	svy_encode q1014 q1014__s

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
	
	save "`workdir'/combined_alc_prev_data.dta", replace
*/
*************************************************************************
***							TABULATE DATASET						   ***
*************************************************************************

use "`workdir'/combined_alc_prev_data.dta", clear

*Drop entries that did not answer the have you ever consumed alcohol question
egen drinkmiss=rowmiss(q4010 q4011 q4012 q4013 q4014 q4015 q4016 q4017) // if all of the drinking questions are missing, drop the case
drop if drinkmiss==8

//ever drink: Question wording is roughly: Have you ever consumed a drink that contains alcohol?, 1 yes, 5 no
gen ever_drinker=0
replace ever_drinker = 1 if q4010==1


//abstainer the reverse of ever_drink
gen lifetime_abstainer = 0
replace lifetime_abstainer =1 if q4010==5

//there looks like the is some inputation funkiness going on. For example, respondents will say they are a lifetime abstainer
//but have values on the showcard answers. Because the instructions from the documentation suggest that if q4010==5, don't go
//on to the showcard. This next block of code overwrites showcard response if they should have been a lifetime abstainer
foreach var of varlist q4011 q4012 q4013 q4014 q4015 q4016 q4017 {
	replace `var'=0 if q4010==5
}


gen binge_times =0
//find the number of times a respondent binge drank
foreach var of varlist q4011 q4012 q4013 q4014 q4015 q4016 q4017 {
	//While we are here set missing drink days to zero. Not the worst assumption in the world, but probably worth rechecking in the future
	replace `var'=0 if `var'==.
	replace binge_times= binge_times+1 if `var'>= 5 //setting binge levels of 5 drinks. Change as neccessary
}

//maximum number of drinks for one day in the last week
egen maxdrink= rowmax(q4011 q4012 q4013 q4014 q4015 q4016 q4017)
gen current_drinker_wk = 0
replace current_drinker_wk=1 if maxdrink>0

//Ever binge drank in the last week
gen ever_binge=0
replace ever_binge = 1 if binge_times>0

/* some old error checking
gen ever_drinker2 = ever_drinker
replace ever_drinker2= 1 if maxdrink>0

gen lifetime_abstainer2=lifetime_abstainer //overwrite question 4010 if the show card answers (q4011-q4018) contain a value greater than 0
replace lifetime_abstainer2 = 0 if maxdrink>0
//current drinker (timeline is in the last week)
gen current_drinker =0
replace current_drinker=1 if maxdrink>0 //if the maximum is over 0, they have consumed alcohol in the last week

//check for mutual exclusivity
*Are these people tagged as both lifetime_abstainers and a current or ever drinker
gen me_check= 0
gen me_check_2=0
gen me_check_3=0
replace me_check =1 if (lifetime_abstainer==1)&(current_drinker==1 | ever_drinker==1)
replace me_check_2=1 if (lifetime_abstainer2==1)&(current_drinker==1 | ever_drinker==1)
replace me_check_3 =1 if (lifetime_abstainer2==1) &ever_drinker2==1
*/


//check for mutual exclusivity
gen me_check =0
replace me_check =1 if lifetime_abstainer==1 &(ever_drinker==1 |  binge_times >0 | current_drinker_wk==1)


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

//case id
gen caseid = _n


//organize the psus as a more interpretable scale (since thier designations are arbitrary for
//our purposes, recode them (keeping the structure the same) so that they are more usable.
tostring psu, gen(psu2)
encode psu2, gen(psu_new)
replace psu_new = -caseid if psu==. //after the encode process, no other psu will be -1, so this is a safe assignment
gen psu_old =psu
replace psu =psu_new


//now reorg strata
tostring strata, gen(strata2)
encode strata2, gen(strata_new)

//fix missing weights and strata
replace pweight =1 if pweight==.
replace strata_new =0 if strata==.
gen strata_old = strata
replace strata = strata_new

save "`workdir'/combined_alc_prev_data_adj.dta", replace



use "`workdir'/combined_alc_prev_data_adj.dta", clear

//testin
*keep if iso3=="GTM" & age_group=="10-20" & sex==1 

//Loop over file, sex and age groups to find the mean values for our variables of interest
qui levelsof file, local(thefiles)

foreach fff of local thefiles {
	levelsof sex if file=="`fff'", local(thesexes)
	levelsof iso3 if file=="`fff'", local(iso)
	foreach sss of local thesexes {
		
		levelsof age_group if sex==`sss', local(theagegroups)
		
		foreach aaa of local theagegroups {
		preserve
		*set trace on
		local iso `iso'
		di "Iso: `iso', Age: `aaa', Sex: `sss' "
		//subset dataset into the desired country/age/sex group
		keep if file =="`fff'" & sex ==`sss' & age_group == "`aaa'"
			
			//only run the following processes if there are any cases left
			if _N>1 {
			//figure out if any strata only have one psu
			//Create Franken strata: the logic according to Grant is below
			// First, we have to combine strata if there are ones with data that only have one psu per strata
			// If there are multiple strata with only one psu, we'll combine them together
			// If there is only one strata that has one psu, we'll combine it with a random other strata -- note by Daniel: I drop it, because I'm tired of this nonsense
			// We reset the psu so that our psus from different strata don't mix when strata are re-assigned.
			qui levelsof strata, local(thestratas)
			local lonelystrata
			foreach stratum of local thestratas {
				qui levelsof psu if strata==`stratum', local(psus)
				local numpsus : list sizeof psus
				*di "THERE ARE `numpsus' psus in strata `stratum'"
				
				//catch the strata that only have 1 psu
				if `numpsus'==1 {
					local lonelystrata `lonelystrata' `stratum'
				}
			}
			*di "the lonely strata are `lonelystrata'"
			local numlone: list sizeof lonelystrata
			di "Number of lonely strata is `numlone' _"
			
			if `numlone' > 1 {
				foreach lonestrat of local lonelystrata {
					replace psu=caseid if strata==`lonestrat' //make sure the PSUs of the new strata don't overlap
					replace strata=0 if strata==`lonestrat' //set obs to the combined strata
				}
			}
			else if `numlone'==1{
				drop if strata==`lonelystrata'
			}
			
			//now that the strata issue has been sorted out, run the svy means.
			//the threshold is set to one because you can't get an SE of just 1 case
			
				svyset psu [pweight=pweight], strata(strata)
				svy: mean ever_drinker lifetime_abstainer current_drinker_wk ever_binge //we'll have to extract binge times seperately because it is only relevant to bingers
						
				//get mean, n and se
				//set trace on
				mat b=e(b)
				mat v=vecdiag((e(V)))
				mat n=e(_N)
				
				*Get some variables before we clear the dataset to make the results dataset
				levelsof year_start, local(styear)
				levelsof year_end, local (endyear)
				local endyear `endyear'
				local styear `styear'
						
				clear
				
				svmat b, names(b_)

				svmat v, names(v_)
				svmat n, names(n_)
				
				
				
				gen file = "`fff'"
				gen iso3 = "`iso'"
				gen sex = `sss'
				gen age_group = "`aaa'"
				gen year_start = `styear'
				gen year_end = `endyear'
				
				tempfile hold
				save `hold', replace
				
				use `master', clear
				append using `hold'
				save `master', replace
			
			}

		restore
		}
	}
}

use `master', clear

save "`workdir'/combined_alc_cat_data.dta", replace
use "`workdir'/combined_alc_cat_data.dta", clear

// ever_drinker lifetime_abstainer current_drinker_wk ever_binge
local b mean
local v se
local n N
local varnames ever_drinker lifetime_abstainer current_drinker_wk ever_binge
tokenize varnames
foreach vartype of varlist b_* v_* n_* {
	local lastchar = substr("`vartype'", strlen("`vartype'"),.)
	local firstchar = substr("`vartype'", 1,1)
	
	*rename `vartype' ``firstchar''_`lastchar'
	
}

qui{
/*	

// tabulate mean drinks among people who drank in last week
	clear
	gen year_start=0
	gen year_end=0
	gen iso3= "TEST"
	gen total_drinks_mean = -123
	gen total_drinks_se = -123
	gen age_group="hold"
	gen sex=3
	gen case=1
	gen total_drinks_sample = 123
//	gen path=""
	tempfile mean_drinks
	save `mean_drinks', replace
	
	
	use "J:\temp\dccasey\Alcohol\AgeSplits\WHS_redo\complete_with_demographics.dta", clear
	cap drop miss
	egen miss = rowmiss(q4011 q4012 q4013 q4014 q4015 q4016 q4017)
	drop if miss == 7
	cap drop total_drinks
	egen total_drinks = rowtotal(q4011 q4012 q4013 q4014 q4015 q4016 q4017)
	
	//CONVERT TO GRAMS PER DAY
	replace total_drinks=(total_drinks*10)/7
	
	// generate age_groups
	cap gen age_group = "80-100" if age >= 80
	forvalues i = 0(5)75 {
		replace age_group = "`i'-`=`i'+5'" if age >= `i' & age < `=`i'+5'
	}
	
	local probisos ARE BIH COM MLI MRT PAK SEN SWZ
	foreach iso of local probisos {
		forvalues i = 0(15)65 {
			replace age_group = "`i'-`=`i'+15'" if age >= `i' & age < `=`i'+15' &iso3=="`iso'"
		}
	}
	
	drop age
	
	//use this switch to toggle include people who had no drinks in the last week
	drop if total_drinks==0
	
	
	//testing
	//keep if year_start==2002 & iso3=="PRY"
	
	//Create a unique rowid per survey
	bysort file: gen caseid=_n
	
	//generate values for missing survey parts
	replace psu =caseid if psu==.
	replace pweight =1 if pweight==.
	replace strata =0 if strata==.
	
	//Fill in missing survey parts
	local iter 2
*
	qui levelsof file, local(files)
	foreach file of local files {
		di "THIS FILE IS `file'"
		levelsof sex, local(sexes)
		
		foreach sss of local sexes {
			qui levelsof age_group if file=="`file'" & sex==`sss', local(ages)
			
			foreach agegrp of local ages {
				preserve
				keep if file=="`file'" & sex==`sss'
				di "dropping file and sex"
				keep if age_group=="`agegrp'"
				di "dropping age group"
				if _N>0 {
				
					//Create Franken strata: the logic according to Grant is below
					// First, we have to combine strata if there are ones with data that only have one psu per strata
					// If there are multiple strata with only one psu, we'll combine them together
					// If there is only one strata that has one psu, we'll combine it with a random other strata -- note by Daniel: I drop it, because I'm tired of this nonsense
					// We reset the psu so that our psus from different strata don't mix when strata are re-assigned.
					di "RUNNING sex: `sss' agegrp: `agegrp'"
					qui levelsof strata, local(thestratas)
					local lonelystrata
					foreach stratum of local thestratas {
						qui levelsof psu if strata==`stratum', local(psus)
						local numpsus : list sizeof psus
						di "THERE ARE `numpsus' psus in strata `stratum'"
						
						//catch the strata that only have 1 psu
						if `numpsus'==1 {
							local lonelystrata `lonelystrata' `stratum'
						}
					}
					di "the lonely strata are `lonelystrata'"
					local numlone: list sizeof lonelystrata
					di "Number of lonely strata is `numlone' _"
					
					if `numlone' > 1 {
						foreach lonestrat of local lonelystrata {
							replace psu=caseid if strata==`lonestrat' //make sure the PSUs of the new strata don't overlap
							replace strata=0 if strata==`lonestrat' //set obs to the combined strata
						}
					}
					else if `numlone'==1{
						drop if strata==`lonelystrata'
					}
					if _N > 0 { //incase there are no cases after of the pareing down
						levelsof iso3, local(iso)
						levelsof year_start, local(startyear)
						levelsof year_end, local(endyear)
						
						di "RUNNING sex: `sss' agegrp: `agegrp' iso:" `iso'
					
						svyset psu [pweight=pweight], strata(strata)
						svy: mean total_drinks
						
						//get mean, n and se
						//set trace on
						mat b=e(b)
						mat v=e(V)
						mat n=e(_N)
						local svyn = n[1,1]
						local svyest = b[1,1]
						local svyse = sqrt(v[1,1])
						
						use `mean_drinks', clear
						set obs `iter'
						
						replace case=_n
						replace year_start=`startyear' if(case==`iter')
						replace year_end=`endyear' if(case==`iter')
						replace iso3= `iso' if(case==`iter')
						replace total_drinks_mean = `svyest' if(case==`iter')
						replace total_drinks_se = `svyse' if(case==`iter')
						replace age_group= "`agegrp'" if(case==`iter')
						replace sex=`sss' if(case==`iter')	
						replace total_drinks_sample =`svyn' if(case==`iter')
						//replace path= "J:/DATA/WHO_WHS/"`iso' if(case==`iter')
						save `mean_drinks', replace
						local iter = `iter'+1
					}
				}
				restore
			}
		}	
	}
	use `mean_drinks', clear
	drop if case==1
	//Rename the variables to match what they represent. This is done at the end to prevent any
	//errors from popping up in the actual processing of the code which was written for total_drinks
	rename total_drinks_mean gramsperday_mean
	rename total_drinks_se gramsperday_se
	rename total_drinks_sample	gramsperday_sample
	
	save "J:\temp\dccasey\Alcohol\AgeSplits\WHS_redo\whsgramsperday.dta",replace
	
	cap log close
	*/
}
