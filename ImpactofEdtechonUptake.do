* Requires: ssc install coefplot
*===============================================================================

clear all
set more off

*-------------------------------------------------------------------------------
* 1. Design
*-------------------------------------------------------------------------------
use "dummy_data.dta", clear
keep if merge_school == 3

gen double stud_per_fcomp = hd_stud_nos_bl / hd_funccomp_nos
xtile stud_per_fcomp_mabv = stud_per_fcomp, nq(2)
gen byte stud_per_fcomp_above = (stud_per_fcomp_mabv == 2)
egen strata = group(stud_per_fcomp_above hd_division)

quietly levelsof strata, local(S)
di as res "strata built: `: word count `S''  (expected 16)"

gen byte mandate = (treatment == 2) if !missing(treatment)
gen byte access  = (treatment == 1) if !missing(treatment)
label var mandate "Mandate"
label var access  "Access"

gen double hd_drpr_hour = hd_drpr / 60

*-------------------------------------------------------------------------------
* 2. The two combined outcomes
*    observed = at least one room's gate was answered. A blank pair means
*    the teacher was not asked, which is different from holding no class,
*    so those stay missing rather than becoming zero.
*-------------------------------------------------------------------------------
quietly foreach s in eng math {

    gen byte tobs_`s' = !missing(tch_lab_so24_`s') | !missing(tch_mmc_so24_`s')

    gen byte ext_`s' = .
    replace  ext_`s' = 0 if tobs_`s' == 1
    replace  ext_`s' = 1 if tch_lab_so24_grde_4_`s' == 1 ///
                          | tch_mmc_so24_grde_4_`s' == 1

    * rowtotal returns 0 when both are blank, right for a teacher who held
    * no class and wrong for one who was never asked, hence the blanking
    egen double tper_`s' = rowtotal(tch_lab_so24_frq_4_`s' tch_mmc_so24_frq_4_`s')
    replace tper_`s' = . if tobs_`s' == 0
    gen double int_`s' = (hd_drpr_hour * tper_`s')/9

    drop tobs_`s'

    label var ext_`s' "Any EdTech class"
    label var int_`s' "Weekly hours"
}

di as txt _n "the combined measures, control group:"
foreach s in eng math {
    quietly summ ext_`s' if treatment == 3
    local e = r(mean)
    quietly summ int_`s' if treatment == 3
    di as res "  " %-6s "`s'" "  extensive " %5.3f `e' ///
              "   intensive " %5.3f r(mean) " hrs/wk"
}

*-------------------------------------------------------------------------------
* 3. Estimate
*-------------------------------------------------------------------------------
eststo clear
foreach s in eng math {
    foreach m in ext int {
        quietly reg `m'_`s' mandate access i.strata, vce(cluster strata)
        eststo `m'_`s'
        quietly summ `m'_`s' if treatment == 3 & e(sample)
        local cm_`m'_`s' : display %4.2f r(mean)
    }
}

*-------------------------------------------------------------------------------
* 4. The four panels
*-------------------------------------------------------------------------------
local ECOL "27 78 125"      // English, deep blue
local MCOL "192 80 77"      // Mathematics, muted red

* shared down a column, with headroom above the widest 90% bound for the label
local XEXT "xscale(range(-0.15 0.45)) xlabel(-0.1(0.1)0.4, labsize(small) format(%3.1f))"
local XINT "xscale(range(-0.25 0.55)) xlabel(-0.2(0.2)0.4, labsize(small) format(%3.1f))"

local BASE                                                                ///
    keep(mandate access) levels(90)                                       ///
    xline(0, lcolor(gs6) lpattern(dash) lwidth(medthin))                  ///
    msymbol(O) msize(large) mlcolor(white) mlwidth(vthin)                 ///
    mlabel(string(@b, "%5.3f"))                                           ///
    mlabposition(12) mlabgap(*2) mlabsize(small)                          ///
    coeflabels(mandate = "Mandate" access = "Access", labsize(medsmall))  ///
    ylabel(, nogrid) grid(none) legend(off)                               ///
    graphregion(color(white)) plotregion(color(white))

*--- A: extensive, English ------------------------------------------------------
coefplot ext_eng, `BASE' `XEXT'                                           ///
    mcolor("`ECOL'") mlabcolor("`ECOL'")                                  ///
    ciopts(recast(rcap) lcolor("`ECOL'") lwidth(medthick))                ///
    title("{bf:Extensive Margin {c 150} English}",                        ///
          size(medsmall) color(gs3) pos(11) span)                         ///
    subtitle("control mean `cm_ext_eng'",                                 ///
             size(vsmall) color(gs7) pos(11) span)                        ///
    xtitle("")                                                            ///
    name(pA, replace)

*--- B: intensive, English ------------------------------------------------------
coefplot int_eng, `BASE' `XINT'                                           ///
    mcolor("`ECOL'") mlabcolor("`ECOL'")                                  ///
    ciopts(recast(rcap) lcolor("`ECOL'") lwidth(medthick))                ///
    title("{bf:Intensive Margin {c 150} English}",                        ///
          size(medsmall) color(gs3) pos(11) span)                         ///
    subtitle("control mean `cm_int_eng' hours per week",                  ///
             size(vsmall) color(gs7) pos(11) span)                        ///
    xtitle("")                                                            ///
    name(pB, replace)

*--- C: extensive, Mathematics --------------------------------------------------
coefplot ext_math, `BASE' `XEXT'                                          ///
    mcolor("`MCOL'") mlabcolor("`MCOL'")                                  ///
    ciopts(recast(rcap) lcolor("`MCOL'") lwidth(medthick))                ///
    title("{bf:Extensive Margin {c 150} Mathematics}",                    ///
          size(medsmall) color(gs3) pos(11) span)                         ///
    subtitle("control mean `cm_ext_math'",                                ///
             size(vsmall) color(gs7) pos(11) span)                        ///
    xtitle("")                                                            ///
    name(pC, replace)

*--- D: intensive, Mathematics --------------------------------------------------
coefplot int_math, `BASE' `XINT'                                          ///
    mcolor("`MCOL'") mlabcolor("`MCOL'")                                  ///
    ciopts(recast(rcap) lcolor("`MCOL'") lwidth(medthick))                ///
    title("{bf:Intensive Margin {c 150} Mathematics}",                    ///
          size(medsmall) color(gs3) pos(11) span)                         ///
    subtitle("control mean `cm_int_math' hours per week",                 ///
             size(vsmall) color(gs7) pos(11) span)                        ///
    xtitle("")                                                            ///
    name(pD, replace)

*-------------------------------------------------------------------------------
* 5. Combine
*    pA pB on the top row, pC pD on the bottom, so extensive runs down the
*    left and intensive down the right.
*-------------------------------------------------------------------------------
graph combine pA pB pC pD,                                                ///
    cols(2) rows(2) xsize(9.4) ysize(6.4) imargin(medium)                 ///
    graphregion(color(white)) plotregion(color(white))                    ///
    title("{bf:Teacher EdTech uptake}", size(large) color(gs2)            ///
          pos(11) span)                                                   ///
    name(margins, replace)

// graph export "teacher_margins.png", replace width(3000)
graph export "teacher_margins.pdf", replace