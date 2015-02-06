clear all
set more off

local datafiles : dir "J:\DATA\WHO_MCSS/" files "*.dta"

foreach file of local datafiles {
	use "J:\DATA\WHO_MCSS/`file'", clear
	di "Using `file'"
	cap confirm weight
	if !_rc {
			di "`file'"
			dasfasdf
			}
		else {
			di "`no weights here'"
		}
	cap confirm pweight	
	if !_rc {
			di "`file'"
			dasfasdf
			}
	else {
			di "`no weights here'"
		}
	
	cap confirm aweight
	if !_rc {
			di "`file'"
			dasfasdf
			}
	else {
			di "`no weights here'"
		}
	cap confirm strata
	if !_rc {
			di "`file'"
			dasfasdf
			}
	else {
			di "`no weights here'"
		}
}
