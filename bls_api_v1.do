qui{
/* 
************************************************************
The programs reads BLS data directly into Stata using the BLS API and jsonio

Purpose: To generate Stata datasets from the BLS without having to bother 
with other programs and json string values. 

Author: James Patrick Henson ⚙
Email 📧: jphenson1218@Gmail.com 
Github 👨‍💻: https://github.com/jphenson
*/
************************************************************
noi di as smcl  "{browse www.jphenson.me:Author-James Patrick Henson}"
noi di as smcl `"{browse "mailto:jphenson1218@gmail.com":jphenson1218@gmail.com}"'
noi di as smcl  "{browse www.github.com/jphenson:Visit my Github for code}"

*****************Program************************************
}
// ⚠⚠ Must run ssc install for the commands below one time before program will work ⚠⚠
// ssc install jsonio


capture program drop bls_api
program define bls_api
	version 15.0
	syntax , [bls_series(string)] [key(string)] [start_year(numlist min=1 max=1)] [end_year(numlist min=1 max=1)] [verbose] 
	di ("`model_1'")
	if "`bls_series'" == "" {
		n di as error "Error: BLS series was left blank"
		exit
	}
	if "`key'" == ""&`end_year'-`start_year'>9 {
		n di as error "Error: 10 year limit without a registration key"
		exit
	}
	if "`key'" != ""&`end_year'-`start_year'>19 {
		n di as error "Error: 20 year limit with a registration key"
		exit
	}
	if "`verbose'" == "" {
		local qui = "qui"
	}
	if "`verbose'" == "verbose" {
		local loud = "n"
	}
	`n' `qui' {
	
	if "`key'" == "" {
		jsonio kv, file("https://api.bls.gov/publicAPI/v2/timeseries/data/`bls_series'?startyear=`start_year'&endyear=`end_year'")
	}
	if "`key'" != "" {
		jsonio kv, file("https://api.bls.gov/publicAPI/v2/timeseries/data/`bls_series'?registrationkey=`key'&startyear=`start_year'&endyear=`end_year'")
	}
    gen new_key = subinstr(key,"/Results/series_1/"," ",.)
	gen str_pos1 = strpos(new_key,"/")
	gen data_list = substr(new_key,1,str_pos1-1)
	gen data_num = subinstr(data_list,"data_","",.)
	destring data_num,replace 
	local bls_series = value[4] 
	label data "This data comes from the BLS data series `bls_series'"
	n di ("This data comes from the BLS data series `bls_series'")
	gen final_key = substr(new_key,str_pos1 + 1,.)
	replace final_key = subinstr(final_key,"footnotes/id_1/","",.)  // consider adding back in later version 
	drop str_pos1 new_key key
	order final_key value data_num
	replace final_key = strtrim(final_key)
	drop if final_key == "status"|final_key == "responseTime"|final_key == "message" | ///
    final_key == "seriesID"|final_key == "latest"|final_key == "code"|final_key == "text" // consider adding latest ,code, text as another var later
	rename value json_value
	local loop_n = data_num[_N]
	local var_N = _N/`loop_n'
	local varlist_1 = ""
	forvalues vari = 1/`var_N'{
		local varname_`vari' = final_key[`vari']
		di ("`varname_`vari''")
		gen `varname_`vari''_pos = `vari'
		local var_list1 = "`var_list1'" + " " + "`varname_`vari''"
		gen str `varname_`vari'' = ""
	}  
	di("`var_list1'")
	foreach var of local var_list1{
		forvalues var_pos = 0/`loop_n' {
			if `var_pos' ==0 {
				replace `var' = json_value[`var'_pos[1]] if _n==1
			}
			if `var_pos' !=0 {
				replace `var' = json_value[`var'_pos[`var_pos']+(`var_pos'*`var_N')] if _n==`var_pos'+1
			}
		}
	}
	// cleanup extra variables 
	foreach var of local var_list1{
		drop `var'_pos 
	}
	drop data_list data_num json_value final_key
	drop if _n>`loop_n'
	}		
end

clear 
cd "C:\Users\Patrick H\Documents\Projects\Dr_Pitts\import_json_data_9_2020\data"

forvalues st_yr = 1939(10)2018{ 
local end_yr = `st_yr'+9
bls_api , bls_series(CES0000000001) start_year(`st_yr') end_year(`end_yr')  // !! This is the final command and the above program can be placed in an .ado file if preferred
save bls_data_`st_yr'_`end_yr'.dta,replace
clear
}
local st_yr = 2019
local end_yr = 2020
bls_api , bls_series(CES0000000001) start_year(`st_yr') end_year(`end_yr')
save bls_data_`st_yr'_`end_yr'.dta,replace
clear
use  bls_data_1939_1948.dta

forvalues st_yr = 1949(10)2018{ 
local end_yr = `st_yr'+9
append using bls_data_`st_yr'_`end_yr'.dta
}
append using bls_data_2019_2020.dta
save bls_CES0000000001_1939_2020.dta,replace 

destring year, replace 
gen month = substr(period, 2,.)
destring month,replace
destring value, gen(value_num)

gen net_change_1 = value_num[_n]-value_num[_n-1]
gen pct_change_1 = round(100*(value_num[_n]-value_num[_n-1])/value_num[_n-1],.1)
gen net_change_3 = value_num[_n]-value_num[_n-3]
gen pct_change_3 = round(100*(value_num[_n]-value_num[_n-3])/value_num[_n-3],.1)
gen net_change_6 = value_num[_n]-value_num[_n-6]
gen pct_change_6 = round(100*(value_num[_n]-value_num[_n-6])/value_num[_n-6],.1)
gen net_change_12 = value_num[_n]-value_num[_n-12]
gen pct_change_12 = round(100*(value_num[_n]-value_num[_n-12])/value_num[_n-12],.1)
drop value
save cleaned_bls_CES0000000001_1939_2020.dta,replace 

// uses my api key 500 daily query limit
// https://www.bls.gov/developers/api_faqs.htm
// under "How is API Version 2.0 different from Version 1.0?"
//bls_api , bls_series(CES0000000001) key(########) start_year(1939) end_year(1955)




