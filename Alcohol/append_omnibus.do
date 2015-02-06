clear all
set more off

local datafiles : dir "J:\temp\dccasey\Alcohol\alc_cat\complete_with_demographics/" files "*.dta"

foreach file of local datafiles {
	append using "J:\temp\dccasey\Alcohol\alc_cat\complete_with_demographics/`files'", clear
}
