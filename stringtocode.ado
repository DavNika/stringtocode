*! version 2.1.5 11nov2026
*! David Nika, German Centre for Higher Education Research and Science Studies
*! Exact dictionary coding; Stata 18 or later. See stringtocode.sthlp.

program define stringtocode, rclass
    version 18.0
    // Commit only on success. Break/errors also trigger Stata's restoration.
    local displaymode = cond(c(noisily), "noisily", "quietly")
    preserve
    capture `displaymode' _stc_run `0'
    local rc = _rc
    if `rc' {
        restore
        exit `rc'
    }
    return add
    restore, not
end

program define _stc_run, rclass
    version 18.0
    syntax varlist(min=1) [if] [in], USING(string) KEY(namelist) ///
        CODE(namelist) [MULTIString NOHarm PROJECTharm NOGtwo KEEPHarm KEEPCode ///
        MULTICode SUFFIXES(string) HARMSuffix(string) CODEType(string) ///
        SPLITCodes STATUS LISTUnmatched UNMATCHED(string) REPLACE]

    marksample touse, novarlist
    tempvar original_order
    quietly generate double `original_order' = _n
    local N = _N
    quietly count if `touse'
    local selected = r(N)
    local nv : word count `varlist'
    local nk : word count `key'
    local nc : word count `code'
    local uk : list uniq key
    local uc : list uniq code
    local overlap : list key & code
    if `: word count `uk'' != `nk' | `: word count `uc'' != `nc' {
        display as error "key() and code() must not contain repeated names."
        exit 198
    }
    if "`overlap'" != "" {
        display as error "key() and code() must contain different variables."
        exit 198
    }
    if "`multistring'" == "" {
        if `nk' != 1 | `nc' != 1 {
            display as error "Without multistring, specify one key and one code variable."
            exit 198
        }
        if "`multicode'`keepcode'" != "" {
            display as error "multicode and keepcode require multistring."
            exit 198
        }
        foreach v of local varlist {
            confirm string variable `v'
        }
    }
    else {
        if `nk' != `nv' {
            display as error "multistring requires one mapping key per input variable, in the same order."
            exit 198
        }
        if "`multicode'" != "" & `nc' > `nv' {
            display as error "multicode cannot have more code variables than input variables."
            exit 198
        }
    }
    if "`suffixes'" == "" local suffixes "_g1 _g2 _f1"
    if `: word count `suffixes'' != 3 {
        display as error "suffixes() requires three suffixes: full code, first code, flag."
        exit 198
    }
    local s1 : word 1 of `suffixes'
    local s2 : word 2 of `suffixes'
    local sf : word 3 of `suffixes'
    if "`s1'" == "`s2'" | "`s1'" == "`sf'" | "`s2'" == "`sf'" {
        display as error "The three suffixes must be different."
        exit 198
    }
    if "`harmsuffix'" == "" local harmsuffix "_harm"
    if "`codetype'" == "" local codetype "auto"
    local codetype = lower("`codetype'")
    if !inlist("`codetype'", "auto", "numeric", "string") {
        display as error "codetype() must be auto, numeric, or string."
        exit 198
    }
    if "`replace'" != "" & `"`unmatched'"' == "" {
        display as error "replace is only for the unmatched() export file."
        exit 198
    }
    if `"`unmatched'"' != "" {
        // Export is .dta only; never overwrite the mapping file itself.
        if !regexm(lower(`"`unmatched'"'), "[.]dta$") local unmatched `"`unmatched'.dta"'
        local mapcheck `"`using'"'
        if !regexm(lower(`"`mapcheck'"'), "[.]dta$") local mapcheck `"`mapcheck'.dta"'
        _stc_path `"`mapcheck'"'
        local mapcheck `"`r(path)'"'
        _stc_path `"`unmatched'"'
        if `"`r(path)'"' == `"`mapcheck'"' {
            display as error "unmatched() must not overwrite the mapping file."
            exit 198
        }
        if "`replace'" == "" confirm new file `"`unmatched'"'
    }

    // Determine output families without imposing a new naming interface.
    if "`multistring'" == "" local bases `varlist'
    else if "`multicode'" == "" local bases : word 1 of `varlist'
    else {
        forvalues j = 1/`nc' {
            local v : word `j' of `varlist'
            local bases `bases' `v'
        }
    }
    local outputs
    foreach b of local bases {
        local outputs `outputs' `b'`s1' `b'`sf'
        if "`nogtwo'" == "" local outputs `outputs' `b'`s2'
        if "`status'" != "" local outputs `outputs' `b'_status
    }
    if "`keepharm'" != "" {
        foreach v of local varlist {
            capture confirm string variable `v'
            if !_rc local outputs `outputs' `v'`harmsuffix'
        }
    }
    if "`keepcode'" != "" local outputs `outputs' `code'
    _stc_newnames `outputs'

    // Internal keys and code columns are always collision-free.
    forvalues j = 1/`nk' {
        tempvar k`j'
        local keys `keys' `k`j''
    }
    forvalues j = 1/`nc' {
        tempvar c`j'
        local codes `codes' `c`j''
    }
    tempfile reportfile
    tempname mapframe summary
    frame create `mapframe'
    frame `mapframe': quietly use `"`using'"', clear
    frame `mapframe': _stc_map, key(`key') code(`code') ///
        keys(`keys') codes(`codes') codetype(`codetype') `keepcode' `splitcodes' `multistring'
    local keytypes `r(keytypes)'
    local mapping_N = r(N)
    // An extra link key prevents excluded/all-empty inputs from matching even
    // if the dictionary contains an all-empty key. Dictionary values stay intact.
    tempvar mapeligible
    frame `mapframe': quietly generate byte `mapeligible' = 1

    local nb : word count `bases'
    matrix `summary' = J(`nb', 8, .)
    matrix colnames `summary' = selected eligible matched coded unmatched emptycode multiple rate
    matrix rownames `summary' = `bases'
    local rounds = cond("`multistring'" == "", `nv', 1)
    local row = 0
    local report_exists = 0
    local generated
    local statusvars
    local harmonized
    local types
    local normalized = 0
    local rawcodes
    if "`keepcode'" != "" local rawcodes "rawcodes(`code')"

    forvalues round = 1/`rounds' {
        if "`multistring'" == "" {
            local inputs : word `round' of `varlist'
            local roundbases `inputs'
        }
        else {
            local inputs `varlist'
            local roundbases `bases'
        }
        tempname work result
        tempvar resultlink
        // Copy only the selected inputs, sample marker and row ID. No merge,
        // sort or normalization is performed on the caller's wide dataset.
        frame put `inputs' `touse' `original_order', into(`work')
        local reportopt
        if "`listunmatched'" != "" | `"`unmatched'"' != "" {
            local reportopt `"reportfile(`"`reportfile'"')"'
            if `report_exists' local reportopt `"`reportopt' appendreport"'
        }
        frame `work': _stc_round `inputs', touse(`touse') ///
            mapframe(`mapframe') mapn(`mapping_N') mapeligible(`mapeligible') keys(`keys') ///
            keytypes(`keytypes') codes(`codes') bases(`roundbases') ///
            suffixes(`suffixes') harmsuffix(`harmsuffix') codetype(`codetype') ///
            `noharm' `projectharm' `nogtwo' `keepharm' `splitcodes' `status' `rawcodes' `reportopt'
        matrix `result' = r(summary)
        local made `r(generated)'
        local kept `r(harmonized)'
        local statusvars `statusvars' `r(statusvars)'
        local types `types' `r(codetypes)'
        local normalized = `normalized' + r(N_normalized)
        local transfer `made' `kept'
        if "`keepcode'" != "" local transfer `transfer' `code'
        _stc_newnames `transfer'
        if _N > 0 {
            quietly frlink 1:1 `original_order', frame(`work') generate(`resultlink')
            _stc_fetch `transfer', from(`work') link(`resultlink')
            drop `resultlink'
        }
        else _stc_fetch `transfer', from(`work') empty
        local generated `generated' `made'
        local harmonized `harmonized' `kept'
        local j = 0
        foreach b of local roundbases {
            local ++row
            local ++j
            forvalues col = 1/8 {
                matrix `summary'[`row', `col'] = `result'[`j', `col']
            }
        }
        if `"`reportopt'"' != "" local report_exists = 1
        frame drop `work'
    }
    frame drop `mapframe'
    // Reorder output columns once, after processing all variables.
    foreach b of local bases {
        local family `b'`s1'
        if "`nogtwo'" == "" local family `family' `b'`s2'
        local family `family' `b'`sf'
        if "`splitcodes'" != "" {
            local j = 1
            local candidate `b'_code`j'
            while `: list candidate in generated' {
                local family `family' `candidate'
                local ++j
                local candidate `b'_code`j'
            }
        }
        if "`status'" != "" local family `family' `b'_status
        order `family', after(`b')
    }
    if "`keepharm'" != "" {
        foreach v of local varlist {
            capture confirm string variable `v'
            if !_rc order `v'`harmsuffix', after(`v')
        }
    }
    // frlink does not reorder the linking (caller) frame.
    drop `original_order'

    // Report/export occurs only after all coding and validation have succeeded.
    if `report_exists' {
        tempname reportframe
        frame create `reportframe'
        frame `reportframe': quietly use `"`reportfile'"', clear
        frame `reportframe': quietly count
        if r(N) > 0 frame `reportframe': gsort source -frequency
        if "`listunmatched'" != "" {
            display as text _newline "Unmatched nonmissing normalized keys (frequencies):"
            frame `reportframe': list, noobs abbreviate(24)
        }
        if `"`unmatched'"' != "" {
            if "`replace'" != "" frame `reportframe': quietly save `"`unmatched'"', replace
            else frame `reportframe': quietly save `"`unmatched'"'
        }
        frame drop `reportframe'
    }
    display as text _newline "stringtocode: exact dictionary coding"
    display as text "Rate = coded / eligible; eligible requires at least one nonmissing key."
    matlist `summary', format(%10.4g) rowtitle(Output)
    return scalar N = `N'
    return scalar N_selected = `selected'
    return scalar N_mapping = `mapping_N'
    return scalar N_outputs = `nb'
    return scalar N_normalized = `normalized'
    return matrix summary = `summary'
    return local generated "`generated'"
    return local harmonized "`harmonized'"
    return local statusvars "`statusvars'"
    return local codetypes "`types'"
    return local codevars "`code'"
    return local suffixes "`suffixes'"
    return local unmatched `"`unmatched'"'
end

program define _stc_newnames
    version 18.0
    // Check both the original dataset and collisions within the planned outputs.
    local names `0'
    local unique : list uniq names
    if `: word count `names'' != `: word count `unique'' {
        display as error "Requested output names collide; change suffixes or input selection."
        exit 198
    }
    foreach name of local names {
        capture confirm name `name'
        if _rc {
            display as error "Invalid or too long output name: `name'"
            exit 198
        }
        capture confirm new variable `name'
        if _rc {
            display as error "Output variable already exists: `name'"
            exit 110
        }
    }
end

program define _stc_map, rclass
    version 18.0
    syntax, KEY(namelist) CODE(namelist) KEYS(namelist) CODES(namelist) ///
        CODEType(string) [KEEPCode SPLITCodes MULTIString]
    confirm variable `key' `code', exact
    keep `key' `code'
    local types
    foreach k of local key {
        capture confirm string variable `k'
        if !_rc {
            // Dictionary key VALUES are authoritative and never normalized.
            // Only lossless storage conversion is allowed for merge's strL limit.
            quietly _stc_keywidth `k'
            local types `types' string
        }
        else local types `types' numeric
        // Composite keys may contain empty components. Uniqueness is checked
        // on the entire tuple below, not on individual key columns.
        if "`multistring'" == "" {
            quietly count if missing(`k')
            if r(N) {
                display as error "Original mapping key `k' has " r(N) " missing values."
                display as error "Remove or complete these mapping rows; missing single keys are not matched."
                exit 459
            }
        }
    }
    if _N {
        tempvar duplicate
        quietly duplicates tag `key', generate(`duplicate')
        quietly count if `duplicate'
        if r(N) {
            display as error "Original mapping keys are not unique: " r(N) " rows."
            display as error "Mapping key values have not been harmonized or changed."
            sort `key'
            quietly keep if `duplicate'
            list `key' `code' in 1/`=min(_N,20)', noobs abbreviate(24)
            exit 459
        }
        drop `duplicate'
    }
    local j = 0
    foreach c of local code {
        local ++j
        local dest : word `j' of `codes'
        capture confirm string variable `c'
        if !_rc quietly generate strL `dest' = `c'
        else quietly generate strL `dest' = strtrim(string(`c', "%24.17g")) if !missing(`c')
        quietly replace `dest' = "" if ustrtrim(`dest') == ""
        quietly _stc_validcodes `dest'
        quietly compress `dest', nocoalesce
        _stc_prepare `dest', codetype(`codetype') `splitcodes'
        // Do not import mapping value-label definitions into the caller.
        capture confirm numeric variable `c'
        if !_rc label values `c'
    }
    rename (`key') (`keys')
    if "`keepcode'" == "" drop `code'
    return local keytypes "`types'"
    return scalar N = _N
end

program define _stc_keywidth
    version 18.0
    syntax varname(string)
    tempvar length
    quietly generate double `length' = strlen(`varlist')
    quietly summarize `length', meanonly
    local width = 1
    if r(N) local width = max(1, r(max))
    if `width' > 2045 {
        display as error "Matching key exceeds the 2045-byte merge limit: `varlist'"
        exit 459
    }
    quietly recast str`width' `varlist'
end

program define _stc_validcodes
    version 18.0
    syntax varname(string)
    quietly count if ustrtrim(`varlist') != "" & ///
        ustrregexm(`varlist', "(^|,)[\p{Z}\s]*(,|$)")
    if r(N) {
        display as error "Malformed code list: " r(N) " rows contain an empty comma-separated component."
        exit 459
    }
end

program define _stc_fetch
    version 18.0
    // Use explicit name=name syntax: frget varlist omits underscore variables.
    syntax namelist, FROM(name) [LINK(name) EMPTY]
    if "`empty'" != "" {
        foreach v of local namelist {
            frame `from': local type : type `v'
            if substr("`type'",1,3)=="str" quietly generate `type' `v' = ""
            else quietly generate `type' `v' = .
        }
    }
    else {
        local pairs
        foreach v of local namelist {
            local pairs `pairs' `v'=`v'
        }
        quietly frget `pairs', from(`link')
    }
end

program define _stc_round, rclass
    version 18.0
    syntax varlist, TOUSE(varname) MAPFrame(name) MAPN(integer) MAPEligible(name) KEYS(namelist) ///
        KEYTypes(namelist) CODES(namelist) BASES(namelist) SUFFIXES(string) ///
        HARMSuffix(string) CODEType(string) [NOHarm PROJECTharm NOGtwo KEEPHarm ///
        SPLITCodes STATUS RAWCodes(namelist) REPORTFile(string) APPENDReport]
    local s1 : word 1 of `suffixes'
    local s2 : word 2 of `suffixes'
    local sf : word 3 of `suffixes'
    tempvar eligible match
    quietly generate byte `eligible' = 0
    local harmonized
    local normalized = 0
    local j = 0
    foreach v of local varlist {
        local ++j
        local k : word `j' of `keys'
        local expected : word `j' of `keytypes'
        capture confirm string variable `v'
        local isstring = (_rc == 0)
        if (`isstring' & "`expected'" != "string") | ///
            (!`isstring' & "`expected'" != "numeric") {
            display as error "Key type mismatch for input `v': mapping expects `expected'."
            exit 109
        }
        if `isstring' {
            _stc_input `v', generate(`k') touse(`touse') `noharm' `projectharm'
            local normalized = `normalized' + r(N_normalized)
            if "`keepharm'" != "" {
                quietly clonevar `v'`harmsuffix' = `k'
                label variable `v'`harmsuffix' "Matching text: `v'"
                local harmonized `harmonized' `v'`harmsuffix'
            }
        }
        else quietly generate double `k' = `v' if `touse'
        quietly replace `eligible' = 1 if `touse' & !missing(`k')
    }
    local emptyopt
    if _N == 0 | `mapn' == 0 {
        quietly generate double `match' = .
        local emptyopt "empty"
    }
    else quietly frlink m:1 `keys' `eligible', ///
        frame(`mapframe' `keys' `mapeligible') generate(`match')
    quietly count if `touse'
    local selected = r(N)
    quietly count if `eligible'
    local ne = r(N)
    quietly count if `eligible' & !missing(`match')
    local nm = r(N)
    local nu = `ne' - `nm'
    local nb : word count `bases'
    tempname summary
    matrix `summary' = J(`nb',8,.)
    local made
    local statuses
    local types
    local j = 0
    foreach b of local bases {
        local ++j
        local c : word `j' of `codes'
        _stc_fetch `c' `c'_multi `c'_t, from(`mapframe') link(`match') `emptyopt'
        quietly count if `eligible' & !missing(`match') & `c' != ""
        local ncode = r(N)
        local nempty = `nm' - `ncode'
        local first `b'`s2'
        if "`nogtwo'" != "" local first `b'`s1'
        _stc_emit `c', generate(`first') mapframe(`mapframe') ///
            link(`match') codetype(`codetype') `emptyopt'
        local types `types' `r(codetype)'
        if "`nogtwo'" == "" {
            rename `c' `b'`s1'
            label variable `b'`s1' "Complete comma-separated code list"
            local family `b'`s1' `first'
        }
        else {
            drop `c'
            local family `first'
        }
        label variable `first' "First code from comma-separated list"
        rename `c'_multi `b'`sf'
        quietly replace `b'`sf' = 0 if `touse' & missing(`b'`sf')
        quietly replace `b'`sf' = . if !`touse'
        label variable `b'`sf' "Multiple comma-separated codes (1=yes, 0=no)"
        local family `family' `b'`sf'
        quietly count if `b'`sf' == 1
        local nmultiple = r(N)
        if "`splitcodes'" != "" {
            _stc_fetch `c'_nparts, from(`mapframe') link(`match') `emptyopt'
            quietly summarize `c'_nparts, meanonly
            local maxcodes = 0
            if r(N) local maxcodes = r(max)
            if `maxcodes' > 0 {
                local splitvars
                forvalues part = 1/`maxcodes' {
                    local splitvars `splitvars' `b'_code`part'
                }
                _stc_newnames `splitvars'
                forvalues part = 1/`maxcodes' {
                    _stc_fetch `c'_s`part'_t, from(`mapframe') link(`match') `emptyopt'
                    _stc_emit `c'_s`part', generate(`b'_code`part') ///
                        mapframe(`mapframe') link(`match') codetype(`codetype') `emptyopt'
                    drop `c'_s`part'_t
                    label variable `b'_code`part' "Code `part' from comma-separated list"
                }
                local family `family' `splitvars'
            }
            drop `c'_nparts
        }
        if "`status'" != "" {
            // Status arrays are constructed only when requested.
            quietly generate byte `b'_status = cond(!`touse', 0, ///
                cond(!`eligible', 1, cond(missing(`match'), 2, ///
                cond(`c'_t == "", 4, 3))))
            label variable `b'_status "Status: 0 excluded; 1 all keys missing; 2 unmatched; 3 coded; 4 empty code"
            local statuses `statuses' `b'_status
            local family `family' `b'_status
        }
        drop `c'_t
        matrix `summary'[`j',1] = (`selected', `ne', `nm', `ncode', ///
            `nu', `nempty', `nmultiple', cond(`ne'>0, `ncode'/`ne', .))
        local made `made' `family'
    }
    if "`rawcodes'" != "" {
        _stc_fetch `rawcodes', from(`mapframe') link(`match') `emptyopt'
    }
    if `"`reportfile'"' != "" {
        tempname reportpart
        frame put `keys' if `eligible' & missing(`match'), into(`reportpart')
        local source : word 1 of `varlist'
        local appendopt
        if "`appendreport'" != "" local appendopt "append"
        frame `reportpart': quietly _stc_report `keys', source(`source') ///
            saving(`"`reportfile'"') `appendopt'
        frame drop `reportpart'
    }
    // Helpers and prepared-code copies exist only in this narrow working frame.
    return matrix summary = `summary'
    return local generated "`made'"
    return local harmonized "`harmonized'"
    return local statusvars "`statuses'"
    return local codetypes "`types'"
    return scalar N_normalized = `normalized'
end

program define _stc_input, rclass
    version 18.0
    syntax varname(string), GENERATE(name) TOUSE(varname) [NOHarm PROJECTharm]
    tempvar raw link
    quietly clonevar `raw' = `varlist'
    quietly replace `raw' = "" if !`touse'
    // No coalescing sort. Fixed strings can be deduplicated for normalization.
    if "`: type `raw''" == "strL" quietly compress `raw', nocoalesce
    if "`noharm'" != "" | _N == 0 {
        quietly clonevar `generate' = `raw'
        quietly _stc_keywidth `generate'
        return scalar N_normalized = 0
        exit
    }
    if "`: type `raw''" == "strL" {
        // Rare fallback: raw >2045-byte values may shrink during normalization.
        quietly clonevar `generate' = `raw'
        quietly _stc_harmonize `generate', `projectharm'
        quietly _stc_keywidth `generate'
        quietly count if `touse' & `raw' != ""
        return scalar N_normalized = r(N)
        exit
    }
    tempname unique
    frame put `raw', into(`unique')
    frame `unique': quietly duplicates drop `raw', force
    frame `unique': quietly clonevar `generate' = `raw'
    frame `unique': quietly count if `raw' != ""
    local n = r(N)
    frame `unique': quietly _stc_harmonize `generate', `projectharm'
    frame `unique': quietly _stc_keywidth `generate'
    quietly frlink m:1 `raw', frame(`unique') generate(`link')
    quietly frget `generate'=`generate', from(`link')
    frame drop `unique'
    return scalar N_normalized = `n'
end

program define _stc_prepare
    version 18.0
    // Parse each dictionary code column ONCE, before looking up any inputs.
    syntax varname(string), CODEType(string) [SPLITCodes]
    local c `varlist'
    quietly generate byte `c'_multi = strpos(`c', ",") > 0
    quietly generate strL `c'_t = ustrtrim(cond(strpos(`c',",") > 0, ///
        substr(`c',1,strpos(`c',",")-1), `c'))
    quietly compress `c'_t, nocoalesce
    _stc_numericinfo `c', codetype(`codetype')
    if "`splitcodes'" != "" {
        tempvar rest pos
        quietly generate long `c'_nparts = cond(`c'=="",0, ///
            1 + strlen(`c') - strlen(subinstr(`c',",","",.)))
        quietly summarize `c'_nparts, meanonly
        local maxcodes = 0
        if r(N) local maxcodes = r(max)
        if `maxcodes' > 0 {
            quietly generate strL `rest' = `c'
            quietly generate double `pos' = .
            forvalues part = 1/`maxcodes' {
                quietly replace `pos' = strpos(`rest',",")
                quietly generate strL `c'_s`part'_t = ustrtrim(cond(`pos'>0, ///
                    substr(`rest',1,`pos'-1),`rest'))
                quietly replace `rest' = cond(`pos'>0, substr(`rest',`pos'+1,.), "")
                quietly compress `c'_s`part'_t, nocoalesce
                _stc_numericinfo `c'_s`part', codetype(`codetype')
            }
        }
    }
end

program define _stc_numericinfo
    version 18.0
    syntax namelist(min=1 max=1 name=prefix), CODEType(string)
    if "`codetype'" == "string" exit
    quietly generate double `prefix'_n = real(`prefix'_t)
    quietly generate byte `prefix'_bad = `prefix'_t != "" & missing(`prefix'_n) & ///
        !regexm(`prefix'_t,"^[.][a-z]?$")
    if "`codetype'" == "auto" {
        quietly generate byte `prefix'_auto = `prefix'_bad | ///
            regexm(`prefix'_t,"^[+-]?0[0-9]") | ///
            strlen(ustrregexra(`prefix'_t,"[^0-9]","")) > 15
    }
    quietly replace `prefix'_bad = 1 if regexm(`prefix'_t,"^[+-]?[0-9]+$") & ///
        abs(`prefix'_n)>9007199254740991 & !missing(`prefix'_n)
end

program define _stc_emit, rclass
    version 18.0
    // Select types using only ACTUALLY MATCHED values; unused dictionary rows
    // must neither force string output nor cause numeric conversion errors.
    syntax namelist(min=1 max=1 name=prefix), GENERATE(name) MAPFrame(name) LINK(name) ///
        CODEType(string) [EMPTY]
    local type "`codetype'"
    if "`type'" == "auto" {
        _stc_fetch `prefix'_auto, from(`mapframe') link(`link') `empty'
        quietly summarize `prefix'_auto, meanonly
        local type "numeric"
        if r(N) > 0 & r(max) > 0 local type "string"
        drop `prefix'_auto
    }
    if "`type'" == "numeric" {
        _stc_fetch `prefix'_bad, from(`mapframe') link(`link') `empty'
        quietly count if `prefix'_bad == 1
        if r(N) {
            display as error "codetype(numeric): matched codes are nonnumeric or exceed exact integer precision."
            exit 459
        }
        drop `prefix'_bad
        // Fetch numeric cache directly under its final name.
        if "`empty'" == "" quietly frget `generate'=`prefix'_n, from(`link')
        else quietly generate double `generate' = .
        format `generate' %24.17g
    }
    else {
        quietly clonevar `generate' = `prefix'_t
        if "`codetype'" == "auto" {
            display as text "`generate': retained as string (text, leading zero, or precision protection)."
        }
    }
    return local codetype "`type'"
end

program define _stc_report
    version 18.0
    syntax varlist, SOURCE(name) SAVING(string) [APPEND]
    if _N quietly contract `varlist', freq(frequency)
    else quietly generate long frequency = .
    local j = 0
    foreach k of local varlist {
        local ++j
        capture confirm numeric variable `k'
        if !_rc {
            tempvar text
            quietly generate str32 `text' = strtrim(string(`k', "%24.17g"))
            drop `k'
            rename `text' `k'
        }
        rename `k' key`j'
    }
    quietly generate str32 source = "`source'"
    order source key* frequency
    if "`append'" != "" quietly append using `"`saving'"'
    quietly save `"`saving'"', replace
end

program define _stc_path, rclass
    version 18.0
    args path
    local path = subinstr(`"`path'"', char(92), "/", .)
    if substr(`"`path'"', 1, 1) != "/" & !regexm(`"`path'"', "^[A-Za-z]:/") {
        local path `"`c(pwd)'/`path'"'
    }
    local path = subinstr(`"`path'"', char(92), "/", .)
    // Resolve ./ and ../ lexically (without requiring the output to exist).
    local rest `"`path'"'
    local stack
    while `"`rest'"' != "" {
        local slash = strpos(`"`rest'"', "/")
        if `slash' {
            local part = substr(`"`rest'"', 1, `slash'-1)
            local rest = substr(`"`rest'"', `slash'+1, .)
        }
        else {
            local part `"`rest'"'
            local rest
        }
        if !inlist(`"`part'"', "/", ".", "") {
            if `"`part'"' == ".." {
                local cut = strlen(`"`stack'"') - strpos(strreverse(`"`stack'"'), "/") + 1
                if `cut' > 0 local stack = substr(`"`stack'"', 1, `cut'-1)
            }
            else local stack `"`stack'/`part'"'
        }
    }
    if "`c(os)'" == "Windows" local stack = lower(`"`stack'"')
    return local path `"`stack'"'
end

program define _stc_harmonize
    version 18.0
    syntax varname(string) [, PROJECTharm]
    local v `varlist'
    // Usually called on DISTINCT raw values, not on every respondent row.
    recast strL `v'
    quietly count if ustrinvalidcnt(`v') > 0
    if r(N) {
        display as error "Invalid UTF-8 in matching text; convert the source encoding first."
        exit 459
    }
    quietly count if strpos(`v', "&") > 0 & strpos(`v', ";") > 0
    if r(N) {
        // All 126 entity passes operate only on the HTML-bearing subset.
        tempvar htmlrow htmllink decoded
        tempname htmlframe
        quietly generate double `htmlrow' = _n
        frame put `v' `htmlrow' if strpos(`v',"&")>0 & strpos(`v',";")>0, into(`htmlframe')
        frame `htmlframe': quietly _stc_html `v'
        quietly frlink 1:1 `htmlrow', frame(`htmlframe') generate(`htmllink')
        quietly frget `decoded'=`v', from(`htmllink')
        quietly replace `v' = `decoded' if !missing(`htmllink')
        drop `htmlrow' `htmllink' `decoded'
        frame drop `htmlframe'
    }
    tempvar nonascii
    quietly generate byte `nonascii' = strlen(`v') != ustrlen(`v')
    replace `v' = upper(`v') if !`nonascii'
    quietly count if `nonascii'
    if r(N) {
        replace `v' = ustrnormalize(`v', "nfc") if `nonascii'
        replace `v' = ustrupper(`v', "en") if `nonascii'
        replace `v' = subinstr(`v', "Ä", "AE", .) if `nonascii'
        replace `v' = subinstr(`v', "Ö", "OE", .) if `nonascii'
        replace `v' = subinstr(`v', "Ü", "UE", .) if `nonascii'
        replace `v' = subinstr(`v', "ẞ", "SS", .) if `nonascii'
        replace `v' = subinstr(`v', "ß", "SS", .) if `nonascii'
        replace `v' = ustrnormalize(`v', "nfd") if `nonascii'
        replace `v' = ustrregexra(`v', "(?<=[A-Z])\p{M}+", "") if `nonascii'
        replace `v' = ustrnormalize(`v', "nfc") if `nonascii'
        replace `v' = subinstr(`v', "Ø", "OE", .) if `nonascii'
        replace `v' = subinstr(`v', "Æ", "AE", .) if `nonascii'
        replace `v' = subinstr(`v', "Œ", "OE", .) if `nonascii'
        replace `v' = subinstr(`v', "Ł", "L", .) if `nonascii'
        replace `v' = subinstr(`v', uchar(8230), "...", .) if `nonascii'
        replace `v' = subinstr(`v', uchar(8411), "...", .) if `nonascii'
        replace `v' = subinstr(`v', uchar(183), ".", .) if `nonascii'
        replace `v' = subinstr(`v', uchar(729), ".", .) if `nonascii'
    }
    // Opt-in project rules after uppercase conversion; inputs only.
    if "`projectharm'" != "" {
        // Match marked and unmarked forms directly; avoid creating ## or <<>>.
        replace `v' = ustrregexra(`v', "#?(2C|3A|27|5C)|<PLS>?|PLS", "")
        replace `v' = subinstr(`v', "#", "", .)
        // Literal backslash-plus is also a separator, without a leftover slash.
        replace `v' = subinstr(`v', char(92) + "+", " ", .)
        replace `v' = subinstr(`v', "+", " ", .)
    }
    replace `v' = ustrregexra(`v', "[\p{Z}\s]+", " ")
    replace `v' = ustrtrim(`v')
end

program define _stc_html
    version 18.0
    syntax varname(string)
    local v `varlist'
    // Finite, case-insensitive decoding; ampersand last, exactly one layer.
    local entities "auml ouml uuml szlig aacute eacute iacute oacute uacute agrave egrave igrave ograve ugrave acirc ecirc icirc ocirc ucirc atilde otilde ntilde aring ccedil cdot ccaron ccirc oslash aelig oelig nbsp ensp emsp thinsp quot apos ldquo rdquo bdquo lsquo rsquo hellip middot centerdot diacriticaldot dot tripledot lt gt"
    local points "196 214 220 223 193 201 205 211 218 192 200 204 210 217 194 202 206 212 219 195 213 209 197 199 266 268 264 216 198 338 32 32 32 32 34 39 34 34 34 39 39 8230 183 183 729 729 8411 60 62"
    quietly count if ustrregexm(`v', "&[A-Za-z]")
    if r(N) {
    local j = 0
    foreach entity of local entities {
        local ++j
        local point : word `j' of `points'
        replace `v' = ustrregexra(`v', "(?i)&`entity';", uchar(`point'))
    }
    }
    // Common decimal/hex entities are decoded consistently with named forms.
    // This finite documented set deliberately avoids a recursive HTML parser.
    quietly count if strpos(`v', "&#") > 0
    if r(N) {
    local numericpoints "196 214 220 223 193 201 205 211 218 192 200 204 210 217 194 202 206 212 219 195 213 209 197 199 266 268 264 216 198 338 32 34 39 8230 183 729 8411 60 62 97 101 105 111 117 228 246 252 225 233 237 243 250 224 232 236 242 249 226 234 238 244 251 227 245 241 229 231 267 269 265 248 230 339 160 9 10 13"
    local hexpoints "c4 d6 dc df c1 c9 cd d3 da c0 c8 cc d2 d9 c2 ca ce d4 db c3 d5 d1 c5 c7 10a 10c 108 d8 c6 152 20 22 27 2026 b7 2d9 20db 3c 3e 61 65 69 6f 75 e4 f6 fc e1 e9 ed f3 fa e0 e8 ec f2 f9 e2 ea ee f4 fb e3 f5 f1 e5 e7 10b 10d 109 f8 e6 153 a0 9 a d"
    local j = 0
    foreach point of local numericpoints {
        local ++j
        local hex : word `j' of `hexpoints'
        replace `v' = ustrregexra(`v', "(?i)&#0*`point';|&#x0*`hex';", uchar(`point'))
    }
    }
    replace `v' = ustrregexra(`v', "(?i)&amp;|&#0*38;|&#x0*26;", uchar(38))
end
