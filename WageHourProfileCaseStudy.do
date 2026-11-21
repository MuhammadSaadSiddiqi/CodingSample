use CPSCleanDataSet.dta, clear

log using "men_wage_hour_profile.txt", replace
// The data was downloaded for men with age between 25-64
// Data Cleaning
// There are total x variables of interest, and the following code cleans it one by one
// The value 9999.99 refers to the "Not in the Universe (NIU)" category, which pertains to survey respondents for whom this information was not applicable. Since no valid value is available for these observations, they were dropped from the analysis. Moreover, individuals with zero earnings were also removed.
drop if earnweek == 9999.99
count
drop if earnweek == 0
count

// Dropping observations below 10 hours as they are not part of the hour bins in paper.
// The dataset also contains observations labeled as "hours vary" and "NIU," which were dropped. Since 99 is the maximum recorded value for hours worked, the code sets appropriate benchmarks and ensures the removal of observations with "hours vary" and "NIU."
drop if missing(uhrswork1) | uhrswork1 < 10 | uhrswork1 > 99
count
// Creating 5-hour bins: 10–14, 15–19, ..., 75–79, 80–99 as mentioned in paper
gen hours_bin = .

replace hours_bin = 10  if inrange(uhrswork1, 10, 14)
replace hours_bin = 15  if inrange(uhrswork1, 15, 19)
replace hours_bin = 20  if inrange(uhrswork1, 20, 24)
replace hours_bin = 25  if inrange(uhrswork1, 25, 29)
replace hours_bin = 30  if inrange(uhrswork1, 30, 34)
replace hours_bin = 35  if inrange(uhrswork1, 35, 39)
replace hours_bin = 40  if inrange(uhrswork1, 40, 44)
replace hours_bin = 45  if inrange(uhrswork1, 45, 49)
replace hours_bin = 50  if inrange(uhrswork1, 50, 54)
replace hours_bin = 55  if inrange(uhrswork1, 55, 59)
replace hours_bin = 60  if inrange(uhrswork1, 60, 64)
replace hours_bin = 65  if inrange(uhrswork1, 65, 69)
replace hours_bin = 70  if inrange(uhrswork1, 70, 74)
replace hours_bin = 75  if inrange(uhrswork1, 75, 79)
replace hours_bin = 80  if inrange(uhrswork1, 80, 99)

// Following code creates dummy variables to estimate the beta coefficients for each hours-worked bin. The 40-hour bin is set as the baseline and excluded to avoid the dummy variable trap. The loop iterates over the bins and generates dummy variables accordingly.

local baseline = 40

//The loop interates and creates dummies for all the hourly bins except for baseline which is 40
levelsof hours_bin, local(bins)
foreach h of local bins {
    if `h' != `baseline' {
        gen hours_`h' = (hours_bin == `h')
    }
}


// dropping imputed values for weekly hours and earnings to stay consistant with author's work

drop if quhrswork1 != 0
drop if qearnwee != 0
count

// Generating an hourly wage variable by dividing weekly earnings with number of hours worked in a week after cleaning both the varibales

gen hourly_wage = earnweek / uhrswork1
// To replicate the paper, we drop observations where the implied hourly wage is less than half of the federal minimum wage ($7.25).

drop if hourly_wage < 0.5*7.29
count


// Initally, the variable, classwkr incuded self-employed professionals as well but after we did the cleaning above those entries have been dropped. Here we are creating a dummy variable to control for employees working with private and public companies in the regression

gen pvt_firm_employee = 0
replace pvt_firm_employee = 1 if (classwkr == 22 | classwkr == 23)

// Drop missing / "not identified" observations. As per my understanding, author is using this to account for difference for living in and outside metropolitian city, so it needs to be a dummy variable

drop if metro == 0 | missing(metro)
count
// Creating dummy variable to use in regression later
gen metro_dummy = 0
replace metro_dummy = 1 if metro != 1 


// Creating another dummy variable. Although paper mentions Black as dummy variable, I used white as it was relatively easier to classify. Race contained around 24 different races with white capturing majority share at 81%. So, I classfied them as white, while the rest of them have been classfied as non-white
gen white_dummy = 0
replace white_dummy = 1 if race == 100

// Creating a dummy variable for ethnicity: 1 = Hispanic, 0 = Non-Hispanic. The original variable has nine categories, with "Not Hispanic" accounting for about 85% of the sample.
gen hispan_dummy = 0
replace hispan_dummy = 1 if hispan != 0
tab hispan_dummy

// Creating dummy for marriage, it has six categories in total
// 0 : married, spouse present
// 1 : married, spouse absent
// 2 : separated
// 3 : divorced
// 4 : widowed
// 5 : never married / single

gen married_dummy = 0
replace married_dummy = 1 if inlist(marst , 0, 1)

// We need to remove cases where an individual is doing two jobs, which restricts our dataset to 95.34% of its original length

drop if multjob == 2
count

// I have added encoded data from CPS to you to show how the mapping is being done
// 2   : none or preschool
// 10  : grades 1, 2, 3, or 4
// 20  : grades 5 or 6
// 30  : grades 7 or 8
// 40  : grade 9
// 50  : grade 10
// 60  : grade 11
// 71  : 12th grade, no diploma
// 73  : high school diploma or equivalent
// 81  : some college but no degree
// 91  : associate's degree, occupational/vocational
// 92  : associate's degree, academic program
// 111 : bachelor's degree
// 123 : master's degree
// 124 : professional school degree
// 125 : doctorate degree

gen educ_cat = .  

// 1 = Less than high school
replace educ_cat = 1 if inlist(educ, 2, 10, 20, 30, 40, 50, 60, 71)

// 2 = High school
replace educ_cat = 2 if inlist(educ, 73, 81)

// 3 = Bachelor's degree
replace educ_cat = 3 if inlist(educ, 91, 92, 111)

// 4 = Graduate degree
replace educ_cat = 4 if inlist(educ, 123, 124, 125)

// Added value labels
label define educ_lbl 1 "Less than high school" 2 "High school" 3 "Bachelor's degree" 4 "Graduate degree"
label values educ_cat educ_lbl

// There are four categories now, creating dummies for 3 keeping less than high school as base line to avoid dummy variable trap

gen educ_hs = (educ_cat == 2)       // High school
gen educ_bach = (educ_cat == 3)     // Bachelor's degree
gen educ_grad = (educ_cat == 4)     // Graduate degree


// Creating a dummy for union membership as paper mentions about controlling this as well
gen union_dummy = 0
replace union_dummy = 1 if union != 1
tab union_dummy

// generating log scale for the dependent variable
gen log_hourly_wage = ln(hourly_wage)


reg log_hourly_wage ///
    hours_10 hours_15 hours_20 hours_25 hours_30 hours_35 ///
    hours_45 hours_50 hours_55 hours_60 hours_65 hours_70 hours_75 hours_80 ///
    age pvt_firm_employee race metro_dummy white_dummy hispan_dummy ///
	married_dummy educ_hs educ_bach educ_grad union_dummy ///
    i.statefip
count

// plotting the regression coefficient on hourly bins with confidence interval. 40 has been set to zero to be the benchmark
preserve

// Collapse to get unique hours_bin values
collapse (count) n=log_hourly_wage, by(hours_bin)

// Initialize coefficient and SE variables
gen coef = .
gen se = .

// Reference category (40 hours) = 0
replace coef = 0 if hours_bin == 40
replace se = 0 if hours_bin == 40

// Extract coefficients for all other hours bins
foreach h in 10 15 20 25 30 35 45 50 55 60 65 70 75 80 {
    replace coef = _b[hours_`h'] if hours_bin == `h'
    replace se = _se[hours_`h'] if hours_bin == `h'
}

* Calculate 95% confidence intervals
gen ci_lower = coef - 1.96*se
gen ci_upper = coef + 1.96*se

* Sort for connected line
sort hours_bin

// Creating figure with descriptive titles

twoway ///
    /// Shaded gray confidence interval area
    (rarea ci_upper ci_lower hours_bin, ///
        fcolor(gs13) lcolor(gs13) lwidth(none)) ///
    /// Connected line with diamond markers
    (connected coef hours_bin, ///
        msymbol(D) msize(medlarge) mcolor(black) mfcolor(black) ///
        lcolor(black) lwidth(medium) lpattern(solid)), ///
    /// X-axis formatting
    xlabel(20(5)80, labsize(small) nogrid) ///
    xtitle("Hours bin (usual weekly hours)", size(small)) ///
    xscale(range(18 82)) ///
    /// Y-axis formatting
    ylabel(-0.5(0.1)0.1, labsize(small) angle(horizontal) format(%3.1f) nogrid) ///
    ytitle("log of Hourly Wages", size(small)) ///
    yscale(range(-0.5 0.12)) ///
    /// Reference lines
    yline(0, lcolor(black) lwidth(thin) lpattern(solid)) ///
    xline(40, lcolor(black) lwidth(thin) lpattern(dash)) ///
    /// Clean white background
    graphregion(color(white) lcolor(white) margin(small)) ///
    plotregion(color(white) lcolor(white) margin(small) style(none)) ///
    /// Descriptive title
    title("Hourly Wages for Men Aged 25-64 Peak at 50Hours & Decline Thereafter", ///
        size(medium) position(11) color(black)) ///
    /// Legend positioned below x-axis label
    legend(order(1 "95% Confidence Interval") ///
        size(vsmall) ///
        position(6) ///
        ring(6) ///
        region(lcolor(white) fcolor(white)) ///
        cols(1)) ///
    /// Use monochrome scheme
    scheme(s2mono)

graph export "men_wage_hour_profile.jpg", replace width(3000) quality(100)

log close