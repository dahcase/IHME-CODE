
		//Drop if the measure != death because lifetables only use deaths
		keep if measure=="death"
		drop measure
		//now drop the values that are not overall of disjoint (zz) parts
		/*
		gen zzpart = strpos(union_type, "zz")
		replace zzpart =1 if union_type=="overall"
		keep if zzpart>0
		drop zzpart
		*/
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
		
		
		//replace union_type = substr(union_type, 4, .)
		
		/*
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
		*/
