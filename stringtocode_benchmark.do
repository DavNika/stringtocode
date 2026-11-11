version 18.0
// Run each ado version in a fresh Stata session with identical arguments.
// Usage: do stringtocode_benchmark.do 10000 50
// Restores data; timer 99 is reserved/cleared by this script.
args observations variables
if "`observations'" == "" local observations 10000
if "`variables'" == "" local variables 50
which stringtocode
capture program drop _stc_benchmark
program define _stc_benchmark
    version 18.0
    args observations variables
    confirm integer number `observations'
    confirm integer number `variables'
    if `observations' < 2 | `variables' < 1 exit 198
    tempfile mapping
    clear
    quietly set obs 4
    quietly generate str30 text = ""
    quietly replace text = "DE" in 1
    quietly replace text = "FRANKREICH" in 2
    quietly replace text = "MUENCHEN" in 3
    quietly replace text = "CAFE" in 4
    quietly generate str16 value = ""
    quietly replace value = "276" in 1
    quietly replace value = "250" in 2
    quietly replace value = "12, 34" in 3
    quietly replace value = "7" in 4
    quietly save `"`mapping'"'
    clear
    quietly set obs `observations'
    quietly generate long rowid = _n
    // Unrelated wide columns expose the cost of repeated full-dataset merges.
    forvalues j = 1/100 {
        quietly generate double background`j' = _n/`j'
    }
    forvalues j = 1/`variables' {
        quietly generate str30 response`j' = ///
            cond(mod(_n+`j',4)==0," de ", ///
            cond(mod(_n+`j',4)==1,"Frankreich", ///
            cond(mod(_n+`j',4)==2,"M&uuml;nchen","Café")))
    }
    timer clear 99
    timer on 99
    capture quietly stringtocode response*, using(`"`mapping'"') key(text) code(value)
    local rc = _rc
    timer off 99
    if `rc' exit `rc'
    assert rowid == _n
    forvalues j = 1/`variables' {
        assert response`j'_g2 == cond(mod(_n+`j',4)==0,276, ///
            cond(mod(_n+`j',4)==1,250,cond(mod(_n+`j',4)==2,12,7)))
    }
    display as text "Observations: `observations'; input variables: `variables'"
    timer list 99
end
preserve
capture noisily _stc_benchmark `observations' `variables'
local rc = _rc
restore
capture program drop _stc_benchmark
if `rc' exit `rc'
