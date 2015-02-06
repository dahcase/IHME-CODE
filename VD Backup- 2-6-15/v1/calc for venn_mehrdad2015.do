clear all

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
*/

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
mat list t
/*
//mat a = .2,.44,.664,.52,.3,.58,.4
//mat list a
//mat list t
local step = 0.5/(`lgt' - 1)
local mn
local sd
foreach num of numlist .1(`step').6 {
	local mn `mn' `num'
	local sdt = `num' / 5
	local sd  `sd' `sdt'
}

drawnorm `lst', n(10) means(`mn') sds(`sd')
gen ab = 1 - (1-a) * (1-b)
gen ac = 1 - (1-a)*(1-c)
gen bc = 1-(1-b)*(1-c)
gen abc = 1-(1-a)*(1-b)*(1-c)
foreach var of varlist * {
	replace `var' = `var' * 10000
}
*/
use J:\WORK\05_risk\other\venn\Results\v57_test6\abc_fra_2010_compare.dta, replace
rename mtbeh x_a
rename mtenv x_b
rename mtmetab x_c
rename mtbeh_metab x_ac
rename mtenv_metab x_bc
rename mtenv_beh x_ab
rename mtall x_abc
aorder 


adsfadsfasdfadsfdsafdsafasdfasdfadsfasdfadsfadsf


mkmat x_*,mat(a)

mata:
	t = st_matrix("t")
	t
	a2 = st_matrix("a")
	//a2
	luinv(t)
	r2 = a2 * luinv(t)
//	r2
//	r2 * t - a2
	st_matrix("results",r2)
end

svmat results, names(res_)
local cnt = 0
foreach var of varlist x_a-x_c {
	local cnt = `cnt' + 1
	rename res_`cnt' `var'_cp
}
