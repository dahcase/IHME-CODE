/*	
	merge m:1 acause using `causetable', keepusing(cause cause_id cause_parent cause_level) keep(3) nogen
	keep age cause sex year iso3 mean_yll mean_yld mean_death acause cause_level cause_parent
	tostring age, replace
	tempfile burden
	save `burden', replace
	
	//Begin acause aggregation!
	
	//Start by bringing the level4s to level3, but before doing that, set a copy of the level4s aside
	use `fullmed', clear
	keep if cause_level==4
	levelsof cause, local(thecauses4)
	tempfile causelev4
	save `causelev4', replace
	
	//merge in the burden estimates of yll ylds
	merge m:1 age sex year iso3 cause using `burden', keepusing(mean_yll mean_yld) keep(3) nogen
	
	//now reopen the burden dataset, find level 4 causes that are not in the risk-cause (e.g. causelev4 temp file)
	//and bring those in to aggregate so that we're not miscounting things
	preserve
	use `burden', clear
	keep if cause_level==4
	//loop through the causes currently address and drop those so we can bring in the ones that are missing
	gen riskcause =0
	foreach var of local thecauses4 {
		replace riskcause = 1 if (cause=="`var'")
	}
	
	drop if riskcause==1 //drop results that have already been calculated
	drop riskcause mean_death acause
	
	tempfile misslev4
	save `misslev4', replace //save to tempfile to be appended later
	
	restore
	append using `misslev4'
	
	*Fix the fact that there are a lot of missing values (e.g. causes that don't have risk factors) by replacing missing with 0
	foreach var of varlist mt* mb* {
		replace `var'=0 if `var'==.
	}
	
	//begin aggregation from level 4 to level 3 causes
	*convert to burden units
	foreach var of varlist mt* {
		gen `var'_yll = `var'*mean_yll
	}
	foreach var of varlist mb* {
		gen `var'_yld = `var'*mean_yld
	}
	drop *_paf
	collapse (sum) *yll *yld, by(iso3 year age sex cause_parent) //sum the burden estimates
	
	*return to paf form
	foreach mt of varlist mt* {
		local newname = substr("`mt'", 1,strlen("`mt'")-4)
		gen `newname' = `mt'/mean_yll
		replace `newname'=0 if `newname' ==.
	}
	
	foreach mb of varlist mb* {
		local newname = substr("`mb'", 1,strlen("`mb'")-4)
		gen `newname' = `mb'/mean_yld
		replace `newname'=0 if `newname' ==.
	}
	
	//drop the old burden estimates
	drop *yll *yld
	rename cause_parent cause //after aggregation the parent becomes the cause
	gen cause_level=3 //change the cause_level to reflect the new reality)
	
	*Drop level 3 causes that were calculated in the mediation process (these are level 3 factors that don't have children) and bring in
	*the ones that have already been calculated
	preserve
	use `fullmed', clear
	
	keep if cause_level==3
	levelsof cause, local(lowlevel3)
	tempfile rclevel3
	save `rclevel3', replace
	restore
	
	//having found what level 3 causes have already been processed, drop the ones we just calculated (and are therefore incorrect)
	//on second thought, this step is probably useless, because any level 3 cause we're adding won't have been calculated because there are no children
	//this bit has be revamped to throw an error if it finds overlap
	foreach ll3 of local lowlevel3 {
		if cause =="`ll3'" {
			di "Cause: `ll3' is here, and it probably shouldn't be"
			HOOOGA BOOGA //my way of forcing stata to throw an error
		}
	}
	
	append using `rclevel3'
	drop cause_parent //this is not necessary for now-- it will be readded in the following loop
	
	//we now have all of the level3 causes in one place, save them and prepare for looped aggregation
	tempfile causelev3
	save `causelev3', replace
	
	local causelevels 2 1 0 //these represent the cause levels that we want to aggregate up too
	
	foreach level of local causelevels {
	
		//merge in the burden estimates of yll ylds
		merge m:1 age sex year iso3 cause using `burden', keepusing(mean_yll mean_yld) keep(3) nogen
		merge m:1 cause using `causetable', keepusing(cause_parent) keep(3) nogen

		//Convert to burden units
		foreach var of varlist mt* {
			gen `var'_yll = `var'*mean_yll
		}
		foreach var of varlist mb* {
			gen `var'_yld = `var'*mean_yld
		}
		drop *_paf
		collapse (sum) *yll *yld, by(iso3 year age sex cause_parent) //collpase burden to the next highest level
		
		
		//convert burden back to paf for the next jump
		foreach mt of varlist mt* {
			local newname = substr("`mt'", 1,strlen("`mt'")-4)
			gen `newname' = `mt'/mean_yll
			replace `newname'=0 if `newname' ==.
		}
		
		foreach mb of varlist mb* {
			local newname = substr("`mb'", 1,strlen("`mb'")-4)
			gen `newname' = `mb'/mean_yld
			replace `newname'=0 if `newname' ==.
		}
		
		//Drop the burden estimates, rename the cause, save to tempfile
		drop *yll *yld
		rename cause_parent cause
		
		gen cause_level=`level'
		
		tempfile causelev`level'
		save `causelev`level'', replace
		
		//run it again!
	}
	//bring all the cause levels together
	append using `causelev4'
	append using `causelev3'
	append using `causelev2'
	append using `causelev1'
	
	drop cause_parent
	//merge m:1 cause using `causetable', keepusing(acause) keep(3) nogen
*/
