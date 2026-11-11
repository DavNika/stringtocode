version 18.0
// Synthetic demonstration. Install stringtocode first. Restores current data.
which stringtocode
capture program drop _stringtocode_example
program define _stringtocode_example
    version 18.0
    tempfile mapping
    clear
    set obs 3
    generate str30 text = "DEUTSCHLAND"
    replace text = "FRANKREICH" in 2
    replace text = "ZWEI LAENDER" in 3
    generate str12 value = "276"
    replace value = "250" in 2
    replace value = "276,250" in 3
    save "`mapping'"
    clear
    set obs 5
    generate str30 response = " deutschland "
    replace response = "Frankreich" in 2
    replace response = "Zwei Laender" in 3
    replace response = "Unbekannt" in 4
    replace response = "" in 5
    stringtocode response, using("`mapping'") key(text) code(value) ///
        keepharm status splitcodes
    return list
    list, noobs
    assert response_g2 == 276 in 1
    assert response_f1 == 1 in 3
    assert response_status == 2 in 4
    assert response_status == 1 in 5
end
preserve
capture noisily _stringtocode_example
local rc = _rc
restore
capture program drop _stringtocode_example
if `rc' exit `rc'
