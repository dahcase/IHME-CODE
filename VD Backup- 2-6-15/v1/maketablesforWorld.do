clear all
set more off

local years 2013
local isos 1
local causes 294 410 491 508 301 296
local age_groups 22
local measures 2
local sexes 3

global prefix "J:"
local vvv "v64_test"

tempfile hold 
save `hold', replace emptyok

local iter 0
foreach year of local years {
	foreach iso of local isos {
		
		import delimited using "J:\WORK\05_risk\other\venn\Results/`vvv'\vdviztool\data_`year'_`iso'.csv", clear
		foreach sex of local sexes {
			foreach age of local age_groups {
				foreach cause of local causes {
					foreach measure of local measures {
						
						preserve
						//keep only all cause for all age, both sex
						keep if cause_id == `cause'
						keep if age_group_id == `age'
						keep if measure_id==`measure'
						keep if sex_id==`sex'
						
						egen overall = max(value)
						
						gen Percent = (value/overall)*100
						
						//bring in the human readable names
						*add a bunch of merge functions here
						//causes
						merge m:1 cause_id using "J:/WORK/00_dimensions/03_causes/causes.dta", keep(3) keepusing(acause cause_name) nogen
						
						//sex
						merge m:1 sex_id using "$prefix/WORK/05_risk/other/venn/dimensions/sex.dta", keep(3) keepusing(name) nogen
						rename name Sex
						
						//age
						merge m:1 age_group_id using "$prefix/WORK/05_risk/other/venn/dimensions/age.dta", keep(3) keepusing(name) nogen
						rename name Age_Group
						
						//measure
						merge m:1 measure_id using "$prefix/WORK/05_risk/other/venn/dimensions/measure.dta", keep(3) keepusing(measure) nogen
						
						gen Year = `year'
						gen location_id = `iso'
						merge m:1 location_id using "$prefix/WORK/05_risk/other/venn/dimensions/location.dta", keep(3) keepusing(name) nogen
						rename name Location
						
						order Location Year Sex Age_Group cause_name union_type Percent measure
						sort Location Year Sex Age_Group acause union_type Percent measure
						
						rename union_type Union_Type
						replace Union_Type = "Environmental" if Union_Type=="202"
						replace Union_Type = "Behavioral" if Union_Type=="203"
						replace Union_Type = "Metabolic" if Union_Type=="204"
						replace Union_Type = "Environmental & Behavioral" if Union_Type=="202_203"
						replace Union_Type = "Environmental & Metabolic" if Union_Type=="202_204"
						replace Union_Type = "Behavioral & Metabolic" if Union_Type=="203_204"
						replace Union_Type = "Environmental & Behavioral & Metabolic" if Union_Type=="202_203_204"
						
						
						
						
						
						rename cause_name Cause_Name
						rename value Value
						rename measure Measure
						tempfile intrim
						save `intrim', replace
						use `hold', clear
						append using `intrim'
						save `hold', replace
						restore

					}
				}
			}
		}
	}
}

use `hold', clear
export delim "J:\WORK\05_risk\other\venn\Results/`vvv'\data_charts_1-21-15.csv", replace

//Now prep for R graphing
keep Location Year Sex Age_Group Cause_Name Union_Type Value cause_id
drop if Union_Type=="overall"

//fix var names
	replace Union_Type = "A" if Union_Type=="Environmental"
	replace Union_Type = "B" if Union_Type=="Behavioral"
	replace Union_Type = "C" if Union_Type=="Metabolic"
	replace Union_Type = "AB" if Union_Type=="Environmental & Behavioral"
	replace Union_Type = "AC" if Union_Type=="Environmental & Metabolic"
	replace Union_Type = "BC" if Union_Type=="Behavioral & Metabolic"
	replace Union_Type = "ABC" if Union_Type=="Environmental & Behavioral & Metabolic"

*reshape wide
reshape wide Value, i(Location Year Sex Age_Group Cause_Name cause_id) j(Union_Type) string

*Replace A, B and C as the disjoint parts
replace ValueA= ValueA- (ValueAB+ValueABC+ValueAC)
replace ValueB= ValueB- (ValueAB+ValueABC+ValueBC)
replace ValueC= ValueC- (ValueABC+ValueAC+ValueBC)

export delim "J:\WORK\05_risk\other\venn\Results/`vvv'\data_charts_1-21-15_R.csv", replace
