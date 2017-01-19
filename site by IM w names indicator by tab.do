/*	Create Site by IM level dataset for SA to include names
	Joshua Davis
	1/18/2017
	Backgroud: at the request of Derek, site by IM w/names
	tabs by indicator

*/

**	01 Merge in Facility and community names

		global data "C:\Users\GHFP\Documents\data\Dec 31 refresh"	//Datasets
		global output "C:\Users\GHFP\Documents\ICPI\SA district profiles\USAID analysis"	//Where the files go

	** Bring in orghierarchy table
		import delimited "C:\Users\GHFP\Documents\data\Nov 15 refresh\OrganizationUnitHierarchy.txt", clear
	** modify to match fact view - drop fiscal year variable
		keep if ïfiscalyear==2016
		drop ïfiscalyear

		* create a unique id by type (facility, community, military)
			* demarcated by f_, c_, and m_ at front
			* military doesn't have a unique id so script uses mechanism uid
		qui: tostring type*, replace //in OUs with no data, . is recorded and 
			* seen as numeric, so need to first string variables 
		qui: gen fcm_uid = ""
			replace fcm_uid = "f_" + facilityuid if facilityuid!=""
			replace fcm_uid = "c_" + communityuid if facilityuid=="" &  ///
				(typecommunity =="Y" | communityuid!="") & typemilitary!="Y"
			*replace fcm_uid = "m_" + mechanismuid if typemilitary=="Y" 

			drop if fcm_uid==""

		**	modificaton for SA

			drop if operatingunit~="South Africa"

		save "$output/orghierarchy table sa.dta", replace

	**	Bring in site by IM factview

		import delimited "$data/ICPI_FactView_Site_By_IM_SouthAfrica_20161230_Q4v2_1.txt", clear

		save "$output/SA site by IM Q4 v2.dta", replace

		u "$output/SA site by IM Q4 v2.dta", clear

		* create a unique id by type (facility, community, military)
			* demarcated by f_, c_, and m_ at front
			* military doesn't have a unique id so script uses mechanism uid
		qui: tostring type*, replace //in OUs with no data, . is recorded and 
			* seen as numeric, so need to first string variables 
		qui: gen fcm_uid = ""
			replace fcm_uid = "f_" + facilityuid if facilityuid!=""
			replace fcm_uid = "c_" + communityuid if facilityuid=="" &  ///
				(typecommunity =="Y" | communityuid!="") & typemilitary!="Y"
			replace fcm_uid = "m_" + mechanismuid if typemilitary=="Y" 


		**	Bring in community and facility id names

		merge m:1 fcm_uid using "$output/orghierarchy table sa.dta"

		save "$output/SA site by IM Q4 v2 w names.dta", replace


		** ** drop not needed

		drop fcm_uid orgunituid orgunitname level typecountry typepsnu ///
		region act pact lts_ta_tc cofinance snu1uid _merge

		** create _POS variables 
		*create new indicator variable for only the ones of interest for analysis
		* for most indicators we just want their Total Numerator reported
		* exceptions = HTC_TST Positives & TX_NET_NEW --> need to "create" new var
		gen key_ind=indicator if (inlist(indicator, "HTC_TST", "CARE_NEW", ///
		"PMTCT_STAT", "PMTCT_ARV", "PMTCT_EID", "TX_NEW", "TX_CURR", ///
		"OVC_SERV", "VMMC_CIRC") | inlist(indicator, "TB_STAT", "TB_ART", ///
		"KP_PREV", "PP_PREV", "CARE_CURR", "TX_RET", "TX_UNDETECT", ///
		"GEND_GBV") | inlist(indicator, "GEND_NORM", "KP_MAT", "PMTCT_FO", ///
		"TB_SCREEN", "KP_MAT", "OVC_ACC")) & disaggregate=="Total Numerator"

		**	keep TX_VIRAL n,d
		replace key_ind=indicator if inlist(indicator,"TX_VIRAL")


		*HTC_TST_POS & TB_STAT_POS indicator
		replace disaggregate="Results" if disaggregate=="Result"
		foreach x in "HTC_TST" "TB_STAT" {
		replace key_ind="`x'_POS" if indicator=="`x'" & ///
		resultstatus=="Positive" & disaggregate=="Results"
		}
		*end
		
		*PMTCT_STAT_POS
		replace key_ind="PMTCT_STAT_POS" if indicator=="PMTCT_STAT" & ///
		disaggregate=="Known/New"

	**	*TX_NET_NEW indicator
			expand 2 if key_ind=="TX_CURR" & , gen(new) //create duplicate of TX_CURR
			replace key_ind= "TX_NET_NEW" if new==1 //rename duplicate TX_NET_NEW
			drop new
		*create copy periods to replace "." w/ 0 for generating net new (if . using in calc --> answer == .)
		foreach x in fy2015q4 fy2016q2 fy2016q4 fy2016_targets{
			clonevar `x'_cc = `x'
			recode `x'_cc (. = 0)
			}
			*end
		*create net new variables (tx_curr must be reporting in both pds)
		gen fy2016q2_nn = fy2016q2_cc-fy2015q4_cc
			replace fy2016q2_nn = . if (fy2016q2==. & fy2015q4==.)
		gen fy2016q4_nn = fy2016q4_cc-fy2016q2_cc
			replace fy2016q4_nn = . if (fy2016q4==. & fy2016q2==.)
		egen fy2016apr_nn = rowtotal(fy2016q2_nn fy2016q4_nn)
		gen fy2016_targets_nn = fy2016_targets_cc - fy2015q4_cc
			replace fy2016_targets_nn = . if fy2016_targets==. & fy2015q4==.
			
		drop *_cc
		*replace raw period values with generated net_new values
		foreach x in fy2016q2 fy2016q4 fy2016apr fy2016_targets {
			replace `x' = `x'_nn if key_ind=="TX_NET_NEW"
			drop `x'_nn
			}
			*end
		*remove tx net new values for fy15
		foreach pd in fy2015q2 fy2015q3 fy2015q4 fy2015apr {
			replace `pd' = . if key_ind=="TX_NET_NEW"
			}
			*end

	* delete extrainous vars/obs
	*drop if key_ind=="" //only need data on key indicators
	drop indicator
	rename key_ind indicator


	**TX

	foreach i in "TX_NEW" "TX_CURR" "TX_RET" "TX_UNDETECT" "TX_NET_NEW" {

			preserve
			keep if indicator=="`i'"
			export excel "$output\SA_APR16_SITE_BY_IM_TX_v1.xlsx", sh("`i'") firstrow(variables)
			restore
				
		}

	**HTC*

	foreach i in "HTC_TST" "HTC_TST_POS" {

			preserve
			keep if indicator=="`i'"
			export excel "$output\SA_APR16_SITE_BY_IM__HTC_v1.xlsx", sh("`i'") firstrow(variables)
			restore
				
		}

	**PMTCT
	foreach i in "PMTCT_STAT" "PMTCT_ARV" "PMTCT_EID" "PMTCT_FO" "PMTCT_STAT_POS" {

			preserve
			keep if indicator=="`i'"
			export excel "$output\SA_APR16_SITE_BY_IM_PMTCT_v1.xlsx", sh("`i'") firstrow(variables)
			restore
				
		}
   

