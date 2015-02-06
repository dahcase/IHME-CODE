clear all
set more off

use "J:\WORK\05_risk\other\venn\Results\v54_2\errorchecks\sexcompare_USA_2013.dta", clear

reshape wide value, i(age cause iso3 year union_type measure) j(sex)
