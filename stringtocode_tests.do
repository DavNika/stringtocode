version 18.0
// Usage: do stringtocode_tests.do "path/to/folder/containing/the/ado"
// A blank argument uses the current working directory. No project data needed.
// The caller's in-memory dataset is restored, even if an assertion fails.
args adodir
if `"`adodir'"' == "" local adodir "."
foreach p in stringtocode _stc_run _stc_newnames _stc_map _stc_keywidth ///
    _stc_validcodes _stc_output _stc_convert _stc_report _stc_path _stc_harmonize ///
    _stc_fetch _stc_round _stc_input _stc_prepare _stc_numericinfo _stc_emit _stc_html {
    capture program drop `p'
}
quietly do `"`adodir'/stringtocode.ado"'
capture program drop _stringtocode_tests

program define _stringtocode_tests
    version 18.0
    tempfile mapping raw numericmap jointmap emptymap badmap report
    tempname summary

    // 1. Harmonization, first/multiple codes, statuses, exclusions and ordering.
    display as text _newline "Test group 1/24: Harmonization, first/multiple codes, statuses, exclusions and ordering."
    clear
    quietly set obs 5
    quietly generate str40 text = ""
    quietly replace text = "MUENCHEN" in 1
    quietly replace text = "CAFE" in 2
    quietly replace text = "BERLIN" in 3
    quietly replace text = "HAUS 27" in 4
    quietly replace text = "DE" in 5
    quietly generate str24 value = ""
    quietly replace value = "12, 34" in 1
    quietly replace value = "07" in 2
    quietly replace value = "" in 3
    quietly replace value = "99" in 4
    quietly replace value = "276" in 5
    save `"`mapping'"', replace
    clear
    quietly set obs 8
    quietly generate long id = .
    quietly replace id = 8 in 1
    quietly replace id = 2 in 2
    quietly replace id = 6 in 3
    quietly replace id = 3 in 4
    quietly replace id = 5 in 5
    quietly replace id = 1 in 6
    quietly replace id = 7 in 7
    quietly replace id = 4 in 8
    quietly generate str40 answer = ""
    quietly replace answer = " MÜNCHEN " in 1
    quietly replace answer = "CAFÉ" in 2
    quietly replace answer = "berlin" in 3
    quietly replace answer = "unbekannt" in 4
    quietly replace answer = "" in 5
    quietly replace answer = "Haus 27" in 6
    quietly replace answer = "DE" in 7
    quietly replace answer = "-999" in 8
    quietly generate byte selected = .
    quietly replace selected = 1 in 1
    quietly replace selected = 1 in 2
    quietly replace selected = 1 in 3
    quietly replace selected = 1 in 4
    quietly replace selected = 1 in 5
    quietly replace selected = 1 in 6
    quietly replace selected = 0 in 7
    quietly replace selected = 1 in 8
    // Existing names that used to collide must survive.
    generate long len = id + 10
    generate byte _merge = 42
    generate str8 value = "original"
    generate str8 text = "original"
    generate str8 answer_copy = "original"
    save `"`raw'"', replace
    stringtocode answer if selected in 1/7, using(`"`mapping'"') ///
        key(text) code(value) keepharm status splitcodes
    matrix `summary' = r(summary)
    assert r(N) == 8
    assert r(N_selected) == 6
    assert r(N_mapping) == 5
    assert r(N_outputs) == 1
    assert `summary'[1,1] == 6
    assert `summary'[1,2] == 5
    assert `summary'[1,3] == 4
    assert `summary'[1,4] == 3
    assert `summary'[1,5] == 1
    assert `summary'[1,6] == 1
    assert `summary'[1,7] == 1
    assert abs(`summary'[1,8] - .6) < 1e-12
    assert answer_g1 == "12, 34" in 1
    confirm string variable answer_g2
    assert answer_g2 == "12" in 1
    assert answer_g2 == "07" in 2
    assert answer_f1 == 1 in 1
    assert answer_f1 == 0 in 2/6
    assert missing(answer_f1) in 7/8
    assert answer_status == 3 in 1/2
    assert answer_status == 4 in 3
    assert answer_status == 2 in 4
    assert answer_status == 1 in 5
    assert answer_status == 3 in 6
    assert answer_status == 0 in 7/8
    assert answer_harm == "MUENCHEN" in 1
    assert answer_harm == "CAFE" in 2
    assert answer_harm == "HAUS 27" in 6
    assert answer_harm == "" in 7/8
    assert answer_code2 == 34 in 1
    assert missing(answer_code2) in 2/8
    assert len == id + 10
    assert _merge == 42
    assert value == "original" & text == "original" & answer_copy == "original"
    assert id == 8 in 1
    assert id == 2 in 2
    assert id == 4 in 8
    assert answer == " MÜNCHEN " in 1

    // 2. Custom suffixes, nogtwo, explicit numeric type and no -999 fallback.
    display as text _newline "Test group 2/24: Custom suffixes, nogtwo, explicit numeric type and no -999 fallback."
    use `"`raw'"', clear
    stringtocode answer, using(`"`mapping'"') key(text) code(value) ///
        suffixes(_codes _first _multi) harmsuffix(_clean) ///
        keepharm nogtwo codetype(numeric)
    confirm numeric variable answer_codes
    capture confirm variable answer_first
    assert _rc == 111
    assert answer_codes == 7 in 2
    assert missing(answer_codes) in 8
    assert answer_multi == 1 in 1
    confirm variable answer_clean

    // 3. Independent input variables: a missing value in one must not exclude another.
    display as text _newline "Test group 3/24: Independent input variables: a missing value in one must not exclude another."
    use `"`raw'"', clear
    generate str10 other = "DE"
    stringtocode answer other, using(`"`mapping'"') key(text) code(value)
    assert other_g2 == 276
    assert answer_g1 == "" in 5

    // 4. noharm leaves inputs unchanged; mapping keys always remain unchanged.
    display as text _newline "Test group 4/24: noharm leaves inputs unchanged; mapping keys always remain unchanged."
    use `"`raw'"', clear
    stringtocode answer, using(`"`mapping'"') key(text) code(value) noharm status
    assert answer_status == 2 in 1/3
    assert answer_status == 2 in 6
    assert answer_status == 3 in 7

    // 5. Numeric mapping codes, composite string/numeric key, fewer outputs.
    display as text _newline "Test group 5/24: Numeric mapping codes, composite string/numeric key, fewer outputs."
    clear
    quietly set obs 2
    quietly generate str20 institution = ""
    quietly replace institution = "UNI KOELN" in 1
    quietly replace institution = "UNI KOELN" in 2
    quietly generate int year = .
    quietly replace year = 2025 in 1
    quietly replace year = 2026 in 2
    quietly generate double number = .
    quietly replace number = 100000001 in 1
    quietly replace number = 200000003 in 2
    quietly generate str10 classification = ""
    quietly replace classification = "A12, B34" in 1
    quietly replace classification = "" in 2
    save `"`jointmap'"', replace
    clear
    quietly set obs 3
    quietly generate str20 name = ""
    quietly replace name = "UNI KOELN" in 1
    quietly replace name = "Uni Köln" in 2
    quietly replace name = "Uni Köln" in 3
    quietly generate int wave = .
    quietly replace wave = 2025 in 1
    quietly replace wave = 2026 in 2
    quietly replace wave = . in 3
    stringtocode name wave, using(`"`jointmap'"') ///
        key(institution year) code(number classification) ///
        multistring multicode keepcode keepharm status splitcodes
    assert name_g2 == 100000001 in 1
    assert name_g2 == 200000003 in 2
    assert name_status == 3 in 1/2
    assert name_status == 2 in 3
    assert wave_g1 == "A12, B34" in 1
    assert wave_g2 == "A12" in 1
    assert wave_status == 4 in 2
    assert wave_code2 == "B34" in 1
    assert number == name_g2 in 1/2
    confirm variable name_harm
    capture confirm variable wave_harm
    assert _rc == 111
    drop name_g1 name_g2 name_f1 name_status name_code1 name_harm ///
        wave_g1 wave_g2 wave_f1 wave_status wave_code1 wave_code2 number classification
    stringtocode name wave, using(`"`jointmap'"') ///
        key(institution year) code(number) multistring multicode
    confirm variable name_g1
    capture confirm variable wave_g1
    assert _rc == 111

    // 6. Dictionary keys identical to input names now work.
    display as text _newline "Test group 6/24: Dictionary keys identical to input names now work."
    clear
    quietly set obs 1
    quietly generate str8 text = ""
    quietly replace text = "DE" in 1
    stringtocode text, using(`"`mapping'"') key(text) code(value)
    assert text_g2 == 276
    assert text == "DE"

    // 7. Rollback after duplicate ORIGINAL keys, even with identical codes.
    display as text _newline "Test group 7/24: Rollback after duplicate ORIGINAL keys, even with identical codes."
    clear
    quietly set obs 2
    quietly generate str20 text = ""
    quietly replace text = "MUENCHEN" in 1
    quietly replace text = "MUENCHEN" in 2
    quietly generate str8 value = ""
    quietly replace value = "1" in 1
    quietly replace value = "1" in 2
    save `"`badmap'"', replace
    use `"`raw'"', clear
    quietly datasignature
    local before `"`r(datasignature)'"'
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`badmap'"') key(text) code(value)
    assert _rc == 459
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`before'"'
    assert id == 8 in 1

    // 8. Rollback after a malformed list or invalid numeric conversion.
    display as text _newline "Test group 8/24: Rollback after a malformed list or invalid numeric conversion."
    clear
    quietly set obs 1
    quietly generate str20 text = ""
    quietly replace text = "DE" in 1
    quietly generate str12 value = ""
    quietly replace value = "12,,34" in 1
    save `"`badmap'"', replace
    use `"`raw'"', clear
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`badmap'"') key(text) code(value)
    assert _rc == 459
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`before'"'
    clear
    quietly set obs 1
    quietly generate str20 text = ""
    quietly replace text = "DE" in 1
    quietly generate str12 value = ""
    quietly replace value = "A12" in 1
    save `"`badmap'"', replace
    use `"`raw'"', clear
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`badmap'"') ///
        key(text) code(value) codetype(numeric)
    assert _rc == 459
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`before'"'

    // 9. Existing output names, retained mapping names, invalid options.
    display as text _newline "Test group 9/24: Existing output names, retained mapping names, invalid options."
    generate byte answer_g1 = 9
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`mapping'"') key(text) code(value)
    assert _rc == 110
    assert answer_g1 == 9
    drop answer_g1
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`mapping'"') ///
        key(text) code(value) multistring keepcode
    assert _rc == 110
    foreach bad in "zofarharm" "delimiter(; )" "stubnames(x)" "missingcodes(-999)" {
        display as text "Expected rejection follows (negative test):"
        capture noisily stringtocode answer, using(`"`mapping'"') key(text) code(value) `bad'
        assert _rc == 198
    }
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`mapping'"') ///
        key(text) code(value) suffixes(_x _x _f)
    assert _rc == 198

    // 10. Empty input, all-empty keys, empty selection and empty dictionary.
    display as text _newline "Test group 10/24: Empty input, all-empty keys, empty selection and empty dictionary."
    clear
    set obs 2
    generate strL answer = ""
    stringtocode answer, using(`"`mapping'"') key(text) code(value) status splitcodes
    assert answer_status == 1
    assert missing(answer_g2)
    assert answer_f1 == 0
    capture confirm variable answer_code1
    assert _rc == 111
    clear
    generate strL answer = ""
    stringtocode answer, using(`"`mapping'"') key(text) code(value)
    assert _N == 0
    confirm variable answer_g1 answer_g2 answer_f1
    clear
    generate str20 text = ""
    generate str12 value = ""
    save `"`emptymap'"', replace
    use `"`raw'"', clear
    stringtocode answer, using(`"`emptymap'"') key(text) code(value) status
    assert answer_status == 2 if answer != ""
    assert answer_status == 1 if answer == ""
    use `"`raw'"', clear
    stringtocode answer if 0, using(`"`mapping'"') key(text) code(value) status
    assert answer_status == 0
    assert missing(answer_f1)

    // 11. Unmatched frequencies, original order, no report for excluded cases.
    display as text _newline "Test group 11/24: Unmatched frequencies, original order, no report for excluded cases."
    use `"`raw'"', clear
    local reportpath `"`report'.dta"'
    stringtocode answer if selected in 1/7, using(`"`mapping'"') ///
        key(text) code(value) unmatched(`"`reportpath'"') listunmatched
    assert id == 8 in 1
    use `"`reportpath'"', clear
    assert _N == 1
    assert source == "answer"
    assert key1 == "UNBEKANNT"
    assert frequency == 1
    erase `"`reportpath'"'

    // 12. Unicode normalization, HTML, safety of ordinary text, numeric entities.
    display as text _newline "Test group 12/24: Unicode normalization, HTML, safety of ordinary text, numeric entities."
    clear
    set obs 6
    generate strL x = ""
    replace x = "Mu" + uchar(776) + "nchen" in 1
    replace x = "&ntilde; &CCEDIL; &Auml;" in 2
    replace x = "Haus 27 2C 3A <PLS> + #" in 3
    replace x = "caf" + uchar(233) + uchar(160) + " " + char(9) + "x" in 4
    replace x = "&#228; &#x00FC; &#38;" in 5
    replace x = "&amp;ntilde;" in 6
    _stc_harmonize x
    assert x == "MUENCHEN" in 1
    assert x == "N C AE" in 2
    assert x == "HAUS 27 2C 3A <PLS> + #" in 3
    assert x == "CAFE X" in 4
    assert x == "AE UE &" in 5
    assert x == "&NTILDE;" in 6

    // 13. Long selected keys fail without truncation; unselected keys are ignored.
    display as text _newline "Test group 13/24: Long selected keys fail without truncation; unselected keys are ignored."
    clear
    set obs 2
    generate strL answer = "DE"
    replace answer = "x" * 2046 in 2
    quietly datasignature
    local before `"`r(datasignature)'"'
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`mapping'"') key(text) code(value)
    assert _rc == 459
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`before'"'
    stringtocode answer in 1, using(`"`mapping'"') key(text) code(value)
    assert answer_g2 == 276 in 1
    assert strlen(answer) == 2046 in 2

    // 14. Large numeric identifier remains a string in automatic mode.
    display as text _newline "Test group 14/24: Large numeric identifier remains a string in automatic mode."
    clear
    quietly set obs 1
    quietly generate str10 text = ""
    quietly replace text = "LARGE" in 1
    quietly generate str24 value = ""
    quietly replace value = "9007199254740993" in 1
    save `"`badmap'"', replace
    clear
    set obs 1
    generate str10 answer = "large"
    stringtocode answer, using(`"`badmap'"') key(text) code(value)
    confirm string variable answer_g2
    assert answer_g2 == "9007199254740993"
    drop answer_g1 answer_g2 answer_f1
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`badmap'"') ///
        key(text) code(value) codetype(numeric)
    assert _rc == 459

    // 15. Type mismatch, missing map key, invalid counts: clean errors.
    display as text _newline "Test group 15/24: Type mismatch, missing map key, invalid counts: clean errors."
    use `"`raw'"', clear
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer selected, using(`"`jointmap'"') ///
        key(year institution) code(number) multistring
    assert _rc == 109
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`jointmap'"') ///
        key(institution year) code(number) multistring
    assert _rc == 198
    clear
    quietly set obs 1
    quietly generate str10 text = ""
    quietly replace text = "" in 1
    quietly generate str5 value = ""
    quietly replace value = "1" in 1
    save `"`badmap'"', replace
    use `"`raw'"', clear
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode answer, using(`"`badmap'"') key(text) code(value)
    assert _rc == 459

    // 16. Mapping values must NEVER be harmonized, even in temporary frames.
    display as text _newline "Test group 16/24: Mapping values must NEVER be harmonized, even in temporary frames."
    // Distinct source keys that would normalize identically must be accepted.
    clear
    quietly set obs 5
    quietly generate str30 text = ""
    quietly replace text = "München" in 1
    quietly replace text = "Muenchen" in 2
    quietly replace text = "MUENCHEN" in 3
    quietly replace text = " DE " in 4
    quietly replace text = "DE" in 5
    quietly generate str8 value = ""
    quietly replace value = "11" in 1
    quietly replace value = "22" in 2
    quietly replace value = "33" in 3
    quietly replace value = "44" in 4
    quietly replace value = "55" in 5
    quietly datasignature
    local mapsignature `"`r(datasignature)'"'
    save `"`badmap'"', replace
    clear
    quietly set obs 4
    quietly generate str30 answer = ""
    quietly replace answer = "München" in 1
    quietly replace answer = "Muenchen" in 2
    quietly replace answer = "MUENCHEN" in 3
    quietly replace answer = " DE " in 4
    tempfile preservation_input
    save `"`preservation_input'"', replace
    stringtocode answer, using(`"`badmap'"') key(text) code(value) status
    assert answer_g2 == 33 in 1/3
    assert answer_g2 == 55 in 4
    use `"`preservation_input'"', clear
    stringtocode answer, using(`"`badmap'"') key(text) code(value) noharm
    assert answer_g2 == 11 in 1
    assert answer_g2 == 22 in 2
    assert answer_g2 == 33 in 3
    assert answer_g2 == 44 in 4
    use `"`badmap'"', clear
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`mapsignature'"'

    // 17. Repeated responses across many variables; original data/order intact.
    display as text _newline "Test group 17/24: Repeated responses across many variables; original data/order intact."
    clear
    quietly set obs 4
    quietly generate str30 text = ""
    quietly replace text = "DE" in 1
    quietly replace text = "MUENCHEN" in 2
    quietly replace text = "UNUSED" in 3
    quietly replace text = "ZERO" in 4
    quietly generate str20 value = ""
    quietly replace value = "276, 250" in 1
    quietly replace value = "9" in 2
    quietly replace value = "ABC" in 3
    quietly replace value = "007" in 4
    save `"`badmap'"', replace
    clear
    set obs 200
    generate long id = 201 - _n
    generate double untouched = _n/7
    forvalues j = 1/20 {
        generate str30 x`j' = cond(mod(_n,2)," de ","M&uuml;nchen")
    }
    quietly stringtocode x1-x20, using(`"`badmap'"') key(text) code(value) status
    assert r(N_normalized) == 40
    matrix `summary' = r(summary)
    assert rowsof(`summary') == 20
    assert id == 201 - _n
    assert untouched == _n/7
    forvalues j = 1/20 {
        assert x`j'_g2 == cond(mod(_n,2),276,9)
        assert x`j'_f1 == mod(_n,2)
        assert x`j'_status == 3
        assert x`j' == cond(mod(_n,2)," de ","M&uuml;nchen")
        assert `summary'[`j',4] == 200
    }
    // Unused nonnumeric mapping entries must not trigger numeric errors.
    generate str2 only = "DE"
    quietly stringtocode only, using(`"`badmap'"') key(text) code(value) codetype(numeric)
    assert only_g2 == 276

    // 18. Automatic type selection is per output, using only matched codes.
    display as text _newline "Test group 18/24: Automatic type selection is per output, using only matched codes."
    clear
    set obs 3
    generate str4 a = "DE"
    generate str4 b = "ZERO"
    quietly stringtocode a b, using(`"`badmap'"') key(text) code(value) splitcodes
    confirm numeric variable a_g2 a_code1 a_code2
    confirm string variable b_g2 b_code1
    assert a_g2 == 276 & a_code2 == 250
    assert b_g2 == "007" & b_code1 == "007"

    // 19. Different raw spellings may share a normalized key; long raw fallback.
    display as text _newline "Test group 19/24: Different raw spellings may share a normalized key; long raw fallback."
    clear
    set obs 5
    generate strL a = "DE"
    replace a = " de " in 2
    replace a = "&#68;E" in 3
    // D is not in the documented numeric-entity table: remains unmatched.
    replace a = "M&uuml;nchen" in 4
    replace a = "DE" + (" " * 2500) in 5
    quietly stringtocode a, using(`"`badmap'"') key(text) code(value) keepharm status
    assert a_g2 == 276 in 1/2
    assert missing(a_g2) & a_status == 2 in 3
    assert a_g2 == 9 in 4
    assert a_g2 == 276 & a_harm == "DE" in 5
    assert strlen(a) == 2502 in 5

    // 20. Multiple-variable unmatched report aggregates within each source.
    display as text _newline "Test group 20/24: Multiple-variable unmatched report aggregates within each source."
    clear
    set obs 4
    generate str10 a = cond(_n<3,"unknown","DE")
    generate str10 b = "unknown"
    quietly stringtocode a b, using(`"`badmap'"') key(text) code(value) ///
        unmatched(`"`reportpath'"') replace
    use `"`reportpath'"', clear
    assert _N == 2
    assert frequency == 2 if source == "a"
    assert frequency == 4 if source == "b"

    // 21. Composite keys with empty first, middle or last components.
    display as text _newline "Test group 21/24: Composite keys with empty first, middle or last components."
    clear
    quietly set obs 4
    quietly generate str12 k1 = ""
    quietly replace k1 = "" in 1
    quietly replace k1 = "ARZT" in 2
    quietly replace k1 = "" in 3
    quietly replace k1 = "" in 4
    quietly generate str12 k2 = ""
    quietly replace k2 = "LEHRER" in 1
    quietly replace k2 = "" in 2
    quietly replace k2 = "" in 3
    quietly replace k2 = "" in 4
    quietly generate str12 k3 = ""
    quietly replace k3 = "" in 1
    quietly replace k3 = "BERLIN" in 2
    quietly replace k3 = "PFLEGE" in 3
    quietly replace k3 = "" in 4
    quietly generate str12 code1 = ""
    quietly replace code1 = "11, 12" in 1
    quietly replace code1 = "22" in 2
    quietly replace code1 = "33" in 3
    quietly replace code1 = "ABC" in 4
    quietly generate str12 code2 = ""
    quietly replace code2 = "101" in 1
    quietly replace code2 = "202" in 2
    quietly replace code2 = "303" in 3
    quietly replace code2 = "999" in 4
    tempfile partialmap partialinput partialreport
    quietly datasignature
    local partialsignature `"`r(datasignature)'"'
    save `"`partialmap'"', replace
    clear
    quietly set obs 8
    quietly generate long id = .
    quietly replace id = 9 in 1
    quietly replace id = 3 in 2
    quietly replace id = 8 in 3
    quietly replace id = 2 in 4
    quietly replace id = 7 in 5
    quietly replace id = 1 in 6
    quietly replace id = 6 in 7
    quietly replace id = 4 in 8
    quietly generate str12 a = ""
    quietly replace a = "" in 1
    quietly replace a = "arzt" in 2
    quietly replace a = "" in 3
    quietly replace a = "" in 4
    quietly replace a = "" in 5
    quietly replace a = "" in 6
    quietly replace a = "lehrer" in 7
    quietly replace a = "" in 8
    quietly generate str12 b = ""
    quietly replace b = "lehrer" in 1
    quietly replace b = "" in 2
    quietly replace b = "" in 3
    quietly replace b = "" in 4
    quietly replace b = "lehrer" in 5
    quietly replace b = "unbekannt" in 6
    quietly replace b = "" in 7
    quietly replace b = "lehrer" in 8
    quietly generate str12 c = ""
    quietly replace c = "" in 1
    quietly replace c = "berlin" in 2
    quietly replace c = "pflege" in 3
    quietly replace c = "" in 4
    quietly replace c = "" in 5
    quietly replace c = "" in 6
    quietly replace c = "" in 7
    quietly replace c = "" in 8
    quietly generate byte selected = .
    quietly replace selected = 1 in 1
    quietly replace selected = 1 in 2
    quietly replace selected = 1 in 3
    quietly replace selected = 1 in 4
    quietly replace selected = 0 in 5
    quietly replace selected = 1 in 6
    quietly replace selected = 1 in 7
    quietly replace selected = 1 in 8
    save `"`partialinput'"', replace
    stringtocode a b c if selected in 1/7, using(`"`partialmap'"') ///
        key(k1 k2 k3) code(code1 code2) multistring multicode keepcode ///
        status splitcodes keepharm unmatched(`"`partialreport'.dta"')
    matrix `summary' = r(summary)
    assert `summary'[1,1] == 6
    assert `summary'[1,2] == 5
    assert `summary'[1,3] == 3
    assert `summary'[1,5] == 2
    assert a_g2 == 11 & a_code2 == 12 & a_f1 == 1 in 1
    assert a_g2 == 22 in 2
    assert a_g2 == 33 in 3
    assert a_status == 1 & missing(a_g2) & code1 == "" in 4
    assert a_status == 0 & missing(a_g2) & missing(a_f1) & code1 == "" in 5
    assert a_status == 2 & missing(a_g2) in 6/7
    assert a_status == 0 & missing(a_g2) & code1 == "" in 8
    assert b_g2 == 101 in 1
    assert b_g2 == 202 in 2
    assert b_g2 == 303 in 3
    assert b_harm == "LEHRER" & a_harm == "" in 1
    assert id == 9 in 1
    assert id == 4 in 8
    use `"`partialreport'.dta"', clear
    assert _N == 2
    assert frequency == 1
    assert (key1 == "" & key2 == "UNBEKANNT") | ///
        (key1 == "LEHRER" & key2 == "")
    erase `"`partialreport'.dta"'
    use `"`partialinput'"', clear
    stringtocode a b c if selected in 1/7, using(`"`partialmap'"') ///
        key(k1 k2 k3) code(code1) multistring nogtwo codetype(numeric)
    assert a_g1 == 11 in 1
    assert missing(a_g1) in 4/8
    use `"`partialmap'"', clear
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`partialsignature'"'
    // Duplicate complete tuples remain an error, even with empty components.
    expand 2 in 1
    save `"`partialmap'"', replace
    use `"`partialinput'"', clear
    display as text "Expected rejection follows (negative test):"
    capture noisily stringtocode a b c, using(`"`partialmap'"') ///
        key(k1 k2 k3) code(code1) multistring
    assert _rc == 459
    capture confirm variable a_g1
    assert _rc == 111

    // 22. Mixed numeric/string keys; extended missing values match exactly.
    display as text _newline "Test group 22/24: Mixed numeric/string keys; extended missing values match exactly."
    clear
    quietly set obs 4
    quietly generate str12 text = ""
    quietly replace text = "LEHRER" in 1
    quietly replace text = "" in 2
    quietly replace text = "LEHRER" in 3
    quietly replace text = "" in 4
    quietly generate double year = .
    quietly replace year = . in 1
    quietly replace year = 2025 in 2
    quietly replace year = .a in 3
    quietly replace year = . in 4
    quietly generate str12 value = ""
    quietly replace value = "11" in 1
    quietly replace value = "22" in 2
    quietly replace value = "33" in 3
    quietly replace value = "ABC" in 4
    save `"`partialmap'"', replace
    clear
    quietly set obs 5
    quietly generate str12 a = ""
    quietly replace a = "LEHRER" in 1
    quietly replace a = "" in 2
    quietly replace a = "LEHRER" in 3
    quietly replace a = "" in 4
    quietly replace a = "LEHRER" in 5
    quietly generate double b = .
    quietly replace b = . in 1
    quietly replace b = 2025 in 2
    quietly replace b = .a in 3
    quietly replace b = . in 4
    quietly replace b = .b in 5
    stringtocode a b, using(`"`partialmap'"') key(text year) code(value) ///
        multistring noharm status
    assert a_g2 == 11 in 1
    assert a_g2 == 22 in 2
    assert a_g2 == 33 in 3
    assert missing(a_g2) & a_status == 1 in 4
    assert missing(a_g2) & a_status == 2 in 5

    // 23. Opt-in project rules, default preservation, noharm and long fallback.
    display as text _newline "Test group 23/24: Opt-in project rules, default preservation, noharm and long fallback."
    clear
    quietly set obs 3
    quietly generate str30 text = ""
    quietly replace text = "LEHRER BERLIN" in 1
    quietly replace text = "LEHRER++BERLIN#2C" in 2
    quietly replace text = "" in 3
    quietly generate str5 value = ""
    quietly replace value = "1" in 1
    quietly replace value = "2" in 2
    quietly replace value = "3" in 3
    // Use multistring for this dictionary so an all-empty key is allowed.
    tempfile projectmap projectinput
    quietly datasignature
    local projectsignature `"`r(datasignature)'"'
    save `"`projectmap'"', replace
    clear
    set obs 4
    generate str30 a = "Lehrer++Berlin#2c"
    replace a = "+#2C+" in 2
    replace a = "LEHRER++BERLIN#2C" in 3
    save `"`projectinput'"', replace
    stringtocode a, using(`"`projectmap'"') key(text) code(value) multistring keepharm
    assert a_harm == "LEHRER++BERLIN#2C" & a_g2 == 2 in 1
    drop a_g1 a_g2 a_f1 a_harm
    stringtocode a in 1/3, using(`"`projectmap'"') key(text) code(value) ///
        multistring projectharm keepharm status
    assert a_harm == "LEHRER BERLIN" & a_g2 == 1 in 1
    assert a_harm == "" & missing(a_g2) & a_status == 1 in 2
    assert a_g2 == 1 in 3
    assert missing(a_g2) & a_status == 0 in 4
    use `"`projectinput'"', clear
    stringtocode a, using(`"`projectmap'"') key(text) code(value) ///
        multistring projectharm noharm keepharm
    assert a_harm == a
    assert missing(a_g2) in 1
    assert a_g2 == 2 in 3
    use `"`projectmap'"', clear
    quietly datasignature
    assert `"`r(datasignature)'"' == `"`projectsignature'"'
    drop if text == ""
    save `"`projectmap'"', replace
    clear
    set obs 2
    generate strL a = "Lehrer++Berlin#2c" + (" " * 2500)
    generate str30 b = "Lehrer++Berlin#2C"
    stringtocode a b, using(`"`projectmap'"') key(text) code(value) projectharm keepharm
    assert a_g2 == 1 & b_g2 == 1
    assert a_harm == "LEHRER BERLIN" & b_harm == "LEHRER BERLIN"
    assert strpos(a,"#2c") > 0

    // 24. Full project artifact set, marked/unmarked, case and separators.
    display as text _newline "Test group 24/24: Full project artifact set, marked/unmarked, case and separators."
    clear
    quietly set obs 8
    quietly generate str100 a = ""
    quietly replace a = "a2cb#2Cc3ad#3Ae27f#27g5ch#5Ci" in 1
    quietly replace a = "aPLSb<pls>c<PlS" in 2
    quietly replace a = "A+B C++D" in 3
    quietly replace a = "1270" in 4
    quietly replace a = "A,B:C" in 5
    quietly replace a = "#2c<pls>#3a#27#5c" in 6
    quietly replace a = "A#B##D" in 7
    quietly replace a = "X##2cY" in 8
    quietly generate str40 expected = ""
    quietly replace expected = "ABCDEFGHI" in 1
    quietly replace expected = "ABC" in 2
    quietly replace expected = "A B C D" in 3
    quietly replace expected = "10" in 4
    quietly replace expected = "A,B:C" in 5
    quietly replace expected = "" in 6
    quietly replace expected = "ABD" in 7
    quietly replace expected = "XY" in 8
    replace a = "A" + char(92) + "+B C" in 3
    tempfile artifacts artifactmap
    save `"`artifacts'"', replace
    generate str40 text = expected
    generate str8 value = string(_n)
    keep text value
    save `"`artifactmap'"', replace
    use `"`artifacts'"', clear
    // End-to-end with missing tuple support and flags.
    stringtocode a, using(`"`artifactmap'"') key(text) code(value) ///
        multistring projectharm keepharm status
    // Row 3 was changed to a literal backslash-plus example.
    assert a_harm == "A B C" in 3
    assert a_status == 2 in 3
    assert a_harm == expected if _n != 3
    assert a_g2 == _n if inlist(_n,1,2,4,5,7,8)
    assert a_status == 1 & missing(a_g2) in 6
    use `"`artifacts'"', clear
    clonevar original = a
    _stc_harmonize a
    assert a == upper(original)

    display as result "All 24 stringtocode test groups passed."
end

preserve
capture noisily _stringtocode_tests
local rc = _rc
restore
capture program drop _stringtocode_tests
if `rc' {
    display as error "stringtocode tests failed; return code `rc'."
    exit `rc'
}
display as result "Tests completed; the original in-memory dataset has been restored."
