clear all
macro drop _all

// Set to run all selected code without pausing
set more off
// Remove previous restores
cap restore, not

if c(os) == "Unix" {
	global prefix "/home/j"
	set odbcmgr unixodbc
	local run 1 //1 means run the dimensions creation process as well
}
else if c(os) == "Windows" {
	global prefix "J:"
	local run 0
}
local version v57_2_testabc
local abccheck 1

if `abccheck'==1 {
	
	
	tempfile abcs
	save `abcs', emptyok
	
	//check to see if the zz parts match their parents
	local abcfiles : dir "$prefix/WORK/05_risk/other/venn/Results/`version'/" files "abc*.dta"
	
	foreach abc of local abcfiles {
		use "$prefix/WORK/05_risk/other/venn/Results/`version'/`abc'", clear
		
		egen ck_mtall = rowtotal(zz_mtall zz_mtbeh zz_mtbeh_metab zz_mtenv zz_mtenv_beh zz_mtenv_metab zz_mtmetab)
		egen ck_mtenv = rowtotal(zz_mtall zz_mtenv zz_mtenv_beh zz_mtenv_metab)
		egen ck_mtbeh = rowtotal(zz_mtall zz_mtbeh zz_mtbeh_metab zz_mtenv_beh)
		egen ck_mtmetab = rowtotal(zz_mtall zz_mtbeh_metab zz_mtenv_metab zz_mtmetab)
		
		
		egen ck_mball = rowtotal(zz_mball zz_mbbeh zz_mbbeh_metab zz_mbenv zz_mbenv_beh zz_mbenv_metab zz_mbmetab)
		egen ck_mbenv = rowtotal(zz_mball zz_mbenv zz_mbenv_beh zz_mbenv_metab)
		egen ck_mbbeh = rowtotal(zz_mball zz_mbbeh zz_mbbeh_metab zz_mbenv_beh)
		egen ck_mbmetab = rowtotal(zz_mball zz_mbbeh_metab zz_mbenv_metab zz_mbmetab)
		
		
		gen dif_mtall = mtall - ck_mtall
		gen dif_mtenv = mtenv - ck_mtenv
		gen dif_mtbeh = mtbeh - ck_mtbeh
		gen dif_mtmetab = mtmetab - ck_mtmetab
		
		gen dif_mball = mball - ck_mball
		gen dif_mbenv = mbenv - ck_mbenv
		gen dif_mbbeh = mbbeh - ck_mbbeh
		gen dif_mbmetab = mbmetab - ck_mbmetab
		
		save "$prefix/WORK/05_risk/other/venn/Results/`version'/errorchecks/ck_`abc'", replace
		keep age cause iso3 sex year dif*
		tempfile toappen
		save `toappen', replace
		use `abcs', clear
		append using `toappen'
		save `abcs', replace
		
	}
}
