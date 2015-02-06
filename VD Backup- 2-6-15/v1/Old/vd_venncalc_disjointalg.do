set more off


local h 
local lst a b c
forval i=1/1 {
	foreach g of local lst {
		foreach g2 of local lst {
			foreach g3 of local lst {
				local k `g' `g2' `g3'
				local k : list uniq k
				local k : list sort k
				local k = subinstr("`k'"," ","",.)
				local h `h' `k'
			}
		}
	}
}
local h : list uniq h
local h : list sort h
local s : list sizeof h
local lgt : list sizeof lst
di `s'
di "`h'"
mat t = J(`s',`s',0)
local row	0
forval row = 1/`s' {	 
	foreach g of local lst {
		local cnt 0
		forval i = 1/`s' {
			local pass 0
			foreach g2 of local lst {
				if (strpos(word("`h'",`i'),"`g2'") > 0 & strpos(word("`h'",`row'),"`g2'") > 0) local pass 1
			}
			if `pass' == 1 {
				mat t[`row',`i'] = 1
			}
		}
	}
}
di "`h'"
*mat list t
*Create the individual parts using Mehrdad's Mata method
aorder
	qui putmata a2=(a ab abc ac bc b c), replace

	mata:
		t = st_matrix("t")
		r2 = a2 * luinv(t)
		r2
		r2 * t - a2
		st_matrix("results",r2)
	end

	svmat results, names(res_)
	local cnt = 0
	foreach var of varlist a-c {
		local cnt = `cnt' + 1
		rename res_`cnt' `var'_zz
	}
