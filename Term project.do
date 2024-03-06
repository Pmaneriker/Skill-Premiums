clear all
set more off
capture log close

*preliminary
****Change directory
cd "/Users/pranjalimaneriker/Documents/econ644/"
log using termproject.log, replace

*****load Rossi's cross-country skill efficiency data
use "AQ_2000.dta", replace
sum
encode country, gen(Country)
********************************************************************************
**********              [1] Descriptive Statistics                **************
********************************************************************************

*Relative skill efficiency
rename irAQ53_dum_skti_hrs_secall r_skillefficiency
label variable r_skillefficiency "Relative Skill efficiency"
tab r_skillefficiency
kdensity r_skillefficiency, title(Kdensity - Relative Skill Efficiency)
graph export "descriptive_fig_1.jpg", replace
gen log_r_skillefficiency = log(r_skillefficiency)
kdensity log_r_skillefficiency, title(Kdensity - Log of skill Efficiency)
graph export "descriptive_fig_2.jpg", replace

*GDP per worker
gen y = exp(l_y)
kdensity y, title(Kdensity - GDP per worker)
graph export "descriptive_fig_3.jpg", replace
kdensity l_y, title(Kdensity - log GDP per worker)
graph export "descriptive_fig_4.jpg", replace
save "cross-country_data.dta", replace

*Cross-country skill efficiency data table
sum Country r_skillefficiency log_r_skillefficiency y l_y

*****load Rossi's clean IPUMS data for US
*Wage
use "usa_clean.dta", replace
gen wage = exp(l_wage)
kdensity wage, title(Kdensity - wage)
graph export "descriptive_fig_5.jpg", replace
kdensity l_wage, title(Kdensity - log wage)
graph export "descriptive_fig_6.jpg", replace

*Personal income
import excel using "Personal Per capita income by U.S. state (2000).xlsx", clear
rename B percapita_income
rename C stateid
kdensity percapita_income, title(Kdensity - Personal per capita income)
graph export "descriptive_fig_7.jpg", replace

********************************************************************************
*******************              [2] Graphs               **********************
********************************************************************************

*****load cross-country skill efficiency data
use "cross-country_data", replace
*****Figure 1 - Replicating Rossi's Figure 1 with a quadratic fit
gen l_y_squared = l_y^2
tw (sc log_r_skillefficiency l_y if sample_micro == 1, mlab(countrycode)) (qfit log_r_skillefficiency l_y if sample_micro == 1), ytitle("Log Relative Skill Efficiency") xtitle("Log GDP per worker") title(Figure 1: Relative Skill efficiency across countries)
graph export "analytical_fig_1.jpg", replace

********************************************************************************
******************             [3] Regressions              ********************
********************************************************************************

*****load Rossi's clean IPUMS data for US
use "usa_clean.dta", replace

/*sample restrictions-use sample from year 2000, keep only employed workers who are wage employees, attached to an employer and have wage data
*/
keep if year == 2000
keep if empstat==1
drop empstat
gen sample_reg=1 if wage_employed==1 & attached==1 & l_wage!=.
keep if sample_reg == 1
save ipums_usa_sample.dta, replace

*US data table 1
sum l_wage edu_num skilled sex exp_group

label define educ_attain 1 "primary or less" 2 "lower secondary" 3 "upper secondary" 4 "some tertiary" 5 "tertiary completed"
label values edu_num educ_attain
graph bar [pw=perwt], over(edu_num, label(labsize(small))) title("Percentage of Educational Attainment" "in the US in year 2000") blabel(bar, format(%9.2gc)) yscale(r(0 40)) ylab(, nogrid)
graph export "descriptive_fig_8.jpg", replace

label define skill_label 0 "unskilled" 1 "skilled"
label values skilled skill_label
graph bar [pw=perwt], over(skilled) blabel(bar, format(%9.2gc)) ylab(, nogrid) title("Percentage of skilled and unskilled workers" "in the US in year 2000")
graph export "descriptive_fig_9.jpg", replace

graph bar [pw=perwt], over(sex) blabel(bar, format(%9.2gc)) ylab(, nogrid) title("Percentage of male and female workers" "in the US in year 2000")
graph export "descriptive_fig_10.jpg", replace

label define experience_label 1 "0-5 years" 2 "6-10 years" 3 "11-15 years" 4 "16-20 years" 5 "21-25 years" 6 "36-30 years" 7 "31-35 years"
label values exp_group_num experience_label
graph bar [pw=perwt], over(exp_group_num, label(labsize(small))) blabel(bar, format(%9.2gc)) ylab(, nogrid) title("Percentage of workers by experience level" "in the US in year 2000")
graph export "descriptive_fig_11.jpg", replace


*Baseline regression
eststo m1: reg l_wage ib3.edu_num [pw=perwt], robust

*With gender controls
eststo m2: reg l_wage ib3.edu_num ib1.sex##i.skilled [pw=perwt], robust

*With experience controls
eststo m3: reg l_wage ib3.edu_num ib1.exp_group_num##i.skilled [pw=perwt], robust

*With experience and gender controls
eststo m4: reg l_wage ib3.edu_num ib1.exp_group_num##i.skilled ib1.sex##i.skilled [pw=perwt], robust

*Multiple regression table
esttab m1 m2 m3 m4 using "multiple regression.tex", keep(1.edu_num 2.edu_num 4.edu_num 5.edu_num 2.sex 2.sex#1.skilled 2.exp_group_num 3.exp_group_num 4.exp_group_num 5.exp_group_num 6.exp_group_num 7.exp_group_num) replace

*Calculate Wage premium by state
bysort statefip:sum l_wage
collapse (mean) l_wage [pw=perwt], by(statefip skilled)
bysort statefip: gen high_wage = l_wage if skilled == 1
bysort statefip: gen low_wage = l_wage if skilled == 0
collapse (mean) high_wage (mean) low_wage, by(statefip)
gen skill_premium = high_wage/low_wage
decode statefip, gen(state)
save skill_premium_bystate.dta, replace

use skill_premium_bystate, replace

import excel using "Personal Per capita income by U.S. state (2000).xlsx", clear
rename B percapita_income
rename C stateid
gen state = lower(A)
merge 1:1 state using skill_premium_bystate
keep if _merge==3
drop _merge

*US data table 2
sum state skill_premium percapita_income 

sc skill_premium percapita_income || qfit skill_premium percapita_income, mlab(stateid) mlabsize(small) xscale(r(60 150)) title(Figure 2: Skill premium across states) xtitle(Personal per capita income) ytitle(Skill premium)

tw (sc skill_premium percapita_income, mlab(stateid) mlabsize(small)) || qfit skill_premium percapita_income, xscale(r(60 150)) title(Figure 2: Skill premium across states) xtitle(Personal per capita income) ytitle(Skill premium) legend(off)
graph export "Skill premium across states.jpg", replace

log close
save skillpremium_percapitaincome_bystate.dta, replace
