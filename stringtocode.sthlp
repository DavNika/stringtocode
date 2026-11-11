{smcl}
{* *! version 2.1.5 11nov2026}{...}
{title:Title}

{pstd}
{bf:stringtocode} {hline 2} Stata module for mapping open-ended responses to codes

{title:Syntax}

{p 8 16 2}
{cmd:stringtocode} {varlist} {ifin}{cmd:,}
{opt using(filename)} {opt key(namelist)} {opt code(namelist)} [{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt multis:tring}}use all inputs jointly as a composite key{p_end}
{synopt:{opt multic:ode}}generate outputs for multiple code columns; requires multistring{p_end}
{synopt:{opt noh:arm}}skip harmonization of input responses{p_end}
{synopt:{opt project:harm}}clean project-specific encoding artifacts in input responses{p_end}
{synopt:{opt nog:two}}retain first code under the full-code output name{p_end}
{synopt:{opt keeph:arm}}retain the string keys used for matching{p_end}
{synopt:{opt keepc:ode}}also retain original mapping code columns; requires multistring{p_end}
{synopt:{opt suffixes(s1 s2 sf)}}output suffixes; default {cmd:_g1 _g2 _f1}{p_end}
{synopt:{opt harms:uffix(s)}}retained-key suffix; default {cmd:_harm}{p_end}
{synopt:{opt codet:ype(type)}}{cmd:auto} (default), {cmd:numeric}, or {cmd:string}{p_end}
{synopt:{opt splitc:odes}}also generate {it:input}{cmd:_code1}, {cmd:_code2}, ...{p_end}
{synopt:{opt status}}generate {it:input}{cmd:_status} for each output family{p_end}
{synopt:{opt listu:nmatched}}list frequencies of unmatched eligible normalized keys{p_end}
{synopt:{opt unmatched(filename)}}save these frequencies in a separate .dta file{p_end}
{synopt:{opt replace}}allow replacement of the unmatched() file only{p_end}
{synoptline}

{title:Description}

{pstd}
{cmd:stringtocode} performs an exact many-to-one lookup in a Stata mapping
dataset. It optionally harmonizes the input responses only, then matches them
against the unchanged dictionary keys and transfers dictionary codes. It does not perform fuzzy, substring, or
semantic matching. Input variables, observation count, and observation order
are preserved. Dictionary files are never modified by the lookup.

{pstd}
Stata 18 or later is required. No external packages, Python, or network
connection are needed. All processing is local.

{title:Matching modes}

{pstd}
Without {cmd:multistring}, all inputs must be strings. Specify exactly one
dictionary key and one code column. Each input is coded independently against
the same dictionary; each receives its own output family.

{pstd}
With {cmd:multistring}, all inputs form one composite key. The number and order
of {cmd:key()} variables must match the inputs. Numeric key components are
allowed and are matched on their stored numeric values. Corresponding keys
must both be numeric or both be strings. Only the first code column generates
an output family, named after the first input. Additional code columns may
be retained with {cmd:keepcode}.

{pstd}
With {cmd:multistring multicode}, code column 1 generates outputs named after
input 1, column 2 after input 2, etc. The number of code columns must not exceed
the number of inputs. All code columns are obtained from the same joint match.
Fewer code columns than inputs are allowed. There is no {cmd:stubnames()} option.

{title:Standard outputs and naming}

{pstd}
For input {cmd:x}, the defaults are:

{p2colset 5 22 24 2}{...}
{p2col:{cmd:x_g1}}Complete code list as a string; original nonempty dictionary spelling is retained.{p_end}
{p2col:{cmd:x_g2}}First comma-separated code, with surrounding Unicode whitespace removed.{p_end}
{p2col:{cmd:x_f1}}1 for multiple codes, 0 otherwise within the selected sample; missing outside it.{p_end}
{p2colreset}{...}

{pstd}
{cmd:suffixes(_codes _first _multi)} replaces these three suffixes, in that
order. Include any desired underscores. The suffixes must be distinct and all
resulting variable names must be valid, at most 32 characters, and new.
Existing variables are never overwritten. {cmd:replace} does not change this.

{pstd}
{cmd:nogtwo} discards the full-code string and puts the first-code variable
under the first output name (normally {cmd:x_g1}). The second output name is
not created. The flag remains and still describes the original list.

{pstd}
{cmd:keepharm} retains string matching copies as {cmd:x_harm}, or with the
suffix chosen by {cmd:harmsuffix()}. Numeric inputs have no harmonized copy.
With {cmd:noharm keepharm}, selected strings are copied without text changes.
Retained matching copies are empty outside the selected sample.

{pstd}
{cmd:keepcode} retains raw dictionary code columns under their original names,
including their original storage types. It requires {cmd:multistring} and
fails if a destination name already exists. These columns are missing for
excluded, all-key-missing, and unmatched observations. Dictionary value-label
definitions and notes are not imported; numeric codes are always stored values.

{title:Harmonization}

{pstd}
One routine is used for every string input. Dictionary key values are never
harmonized, including in temporary working frames. They must already contain
the spellings to which the processed responses should match. For example,
with default harmonization, an input of Muenchen or München matches the
dictionary key MUENCHEN; the keys München and Muenchen remain distinct unused
alternatives unless noharm is specified. The input routine applies these rules:

{phang}1. Decode one layer of supported HTML entities, case-insensitively.
Supported named entities are {cmd:auml ouml uuml szlig aacute eacute iacute
oacute uacute agrave egrave igrave ograve ugrave acirc ecirc icirc ocirc ucirc
atilde otilde ntilde aring ccedil cdot ccaron ccirc oslash aelig oelig nbsp
ensp emsp thinsp quot apos ldquo rdquo bdquo lsquo rsquo hellip middot
centerdot diacriticaldot dot tripledot lt gt amp}, enclosed in {cmd:&} and
{cmd:;}. Upper/lower variants intentionally converge during uppercasing.

{phang}2. Decode decimal/hex numeric entities for the same character set and
its listed lowercase Latin counterparts, nonbreaking space, tab, LF and CR;
also lowercase ASCII vowels. This is a finite lookup, not a general HTML
decoder. Unsupported entities remain literal. Ampersand is decoded last to
avoid recursive decoding.

{phang}3. Normalize Unicode to NFC and uppercase with the fixed {cmd:en}
locale, independent of the user's current locale.

{phang}4. Convert {cmd:AE/OE/UE} from German umlauts and {cmd:SS} from sharp s.
After NFD decomposition, remove combining marks directly following ASCII
Latin base letters, then recompose to NFC. Other scripts are retained.
Additionally map O-stroke to {cmd:OE}, AE/OE ligatures to {cmd:AE/OE}, and
L-stroke to {cmd:L}.

{phang}5. Map ellipsis and combining three dots to {cmd:...}, and middle/dot
above characters to {cmd:.}. Collapse Unicode separator/whitespace runs to
one ordinary space and trim both ends.

{pstd}
By default, the routine does not delete ordinary digits, {cmd:27}, {cmd:2C},
{cmd:3A}, {cmd:<PLS>}, plus signs, or hash signs. {cmd:zofarharm} has been
removed and is rejected as an unknown option. {cmd:noharm} bypasses all text
changes to input responses, including {cmd:projectharm} when both are specified.
Mapping key values are unchanged regardless of these options.
Type, length, and uniqueness checks still apply.

{pstd}
{cmd:projectharm} removes the following sequences anywhere in input text,
after case conversion: {cmd:2C}, {cmd:3A}, {cmd:27}, and {cmd:5C}, each with or
without a preceding {cmd:#}; also {cmd:PLS}, {cmd:<PLS>}, and {cmd:<PLS}
(without a closing bracket). Lowercase and mixed-case forms are covered by
uppercase conversion. Marked forms are removed as a whole, without introducing
extra hash signs or angle brackets. These are literal substring rules, not
word-boundary rules: {cmd:1270} becomes {cmd:10}. All remaining literal
{cmd:#} characters are then deleted; {cmd:A#B##C} becomes {cmd:ABC}.

{pstd}
Literal backslash-plus and ordinary {cmd:+} are replaced by spaces, followed by
whitespace collapsing/trimming. For example, {cmd:Lehrer++Berlin#2c} becomes
{cmd:LEHRER BERLIN}. Plus replacement applies even when other spaces already
exist. Standalone backslashes, ordinary commas and colons are not removed by
these project rules. The option works with both independent inputs and
{cmd:multistring}; {cmd:keepharm} shows the resulting keys. Mapping keys remain
unchanged; {cmd:noharm} overrides {cmd:projectharm}.

{phang2}{cmd:. stringtocode answer, using("mapping.dta") key(text) code(value) projectharm keepharm}

{pstd}
Invalid UTF-8 is rejected during harmonization. String matching keys must fit
within 2045 bytes (inputs after harmonization, mapping keys as stored).
strL inputs are accepted when their
selected matching values fit this limit. Strings are never silently truncated.
Unselected input values are not harmonized or checked for key length.

{title:Dictionary validation and missing values}

{pstd}
Original mapping keys must be unique exactly as supplied, even when duplicate
rows have identical codes. For {cmd:multistring}, uniqueness is checked on the
whole combination, including missing components. No normalization is performed
before this check. Up to 20 duplicate rows are listed on failure. Missing
dictionary keys are rejected only without {cmd:multistring}. An empty dictionary with correctly typed
columns is allowed and produces no matches. key() and code() must contain
distinct, nonrepeated, exact variable names (no wildcards or ranges).

{pstd}
With {cmd:multistring}, an input is eligible when at least one matching key is
nonmissing. Empty components are matched exactly in their original positions;
they are not wildcards. For example, empty/LEHRER/empty can match the same
combination in the dictionary. Numeric missing values also match exactly:
{cmd:.}, {cmd:.a}, and {cmd:.b} are distinct key values. Inputs with all key
components missing are never matched, even if an all-missing dictionary row
exists. Without {cmd:multistring}, a missing input key is not matched.
Without {cmd:noharm}, whitespace-only strings become missing keys. With {cmd:noharm}, only the empty string is a missing string key.
Whitespace-only dictionary codes count as empty codes, independently of
{cmd:noharm}. Numeric missing dictionary codes, including extended missings,
count as empty; string codes {cmd:"."} and {cmd:".a"} remain explicit codes.

{pstd}
There is no special treatment of {cmd:-999} or other project-specific values.
Include them explicitly in the mapping if needed. No {cmd:missingcodes()},
{cmd:nomissingcodes}, or {cmd:matchmissing} option exists.

{title:Code types and comma-separated lists}

{pstd}
The comma is the only delimiter. There is no delimiter() option. All code
columns in code() are validated, including retained-only columns. Nonempty
lists with an empty component (for example {cmd:"12,"}, {cmd:",12"}, or
{cmd:"12,,34"}) cause an error. Whitespace is trimmed for individual-code
outputs. Repeated nonempty components such as {cmd:"12,12"} are retained
and flagged as multiple components. Order is preserved.

{pstd}
Code columns may be strings or numeric. Numeric mapping codes are converted
to text with {cmd:%24.17g}; already rounded source values cannot be recovered.
For numeric dictionary missing values the full-code output is empty.

{phang}{cmd:codetype(auto)} converts each first-code output to double if all
its nonempty values can be represented numerically, have no leading-zero
identifier pattern, and contain at most 15 digit characters. Otherwise that
entire output remains a string and a notice is displayed. The digit-count
rule is deliberately conservative, including for scientific notation and
decimals. A completely empty output becomes numeric missing.

{phang}{cmd:codetype(numeric)} requires numeric conversion and rejects invalid
values or integer strings beyond the exact double-integer range. Leading
zeros are intentionally discarded. Decimal/scientific values use Stata's
ordinary double precision; choose string to retain exact textual forms.

{phang}{cmd:codetype(string)} retains trimmed individual codes as strings.

{pstd}
String representations of numeric missing values {cmd:.} and {cmd:.a-.z}
are accepted during conversion. For reporting, a nonempty string code is
considered assigned even if its numeric representation is a Stata missing.

{pstd}
{cmd:splitcodes} additionally generates {it:input}{cmd:_code1},
{it:input}{cmd:_code2}, etc., up to the maximum number of codes among selected
matched observations for that output. No split variables are created if
there are no assigned codes. Each split variable independently follows
codetype(). Their fixed suffixes do not depend on suffixes(). Existing-name
conflicts cause an error and roll back the operation. splitcodes may be
combined with nogtwo.

{title:Sample restrictions and status}

{pstd}
{cmd:if} and {cmd:in} refer to the original observation order and are both
honored. All observations are retained. Code, flag, and split outputs are
missing outside the selection. Status is 0 outside the selection.

{pstd}
{cmd:status} adds {it:input}{cmd:_status} to each output family:

{p2colset 5 12 14 2}{...}
{p2col:{cmd:0}}Not selected by if/in.{p_end}
{p2col:{cmd:1}}Selected, but all matching keys are missing.{p_end}
{p2col:{cmd:2}}Eligible key combination, no mapping entry found.{p_end}
{p2col:{cmd:3}}Mapping entry found and this output has a nonempty code.{p_end}
{p2col:{cmd:4}}Mapping entry found, but this output's code is empty.{p_end}
{p2colreset}{...}

{pstd}
With multicode, statuses 0-2 agree across families, whereas 3/4 can differ
by code column. Status names use the fixed suffix _status. No global value
label definitions are created or overwritten; meanings are in variable labels.

{title:Unmatched reports and returned results}

{pstd}
{cmd:listunmatched} displays frequencies of selected, eligible normalized
keys with no dictionary match. Missing input keys and matched-but-empty codes
are excluded. {cmd:unmatched(filename)} saves the same information to .dta;
.dta is appended when omitted. With no unmatched keys, a zero-row report
with the same columns is saved. Existing files require {cmd:replace}.

{pstd}
Report columns are {cmd:source} (input name, or first input in joint mode),
{cmd:key1}, ..., {cmd:keyK} (matching values as strings), and {cmd:frequency}.
Different original spellings that normalize to one key are counted together.
No original response text or respondent identifier is exported. Reports for
simple-mode inputs remain separate via source. Numeric keys use %24.17g.

{pstd}
The summary table has one row per output family. Results in {cmd:r()} are:

{p2colset 5 25 27 2}{...}
{p2col:{cmd:r(N)}}Original number of observations.{p_end}
{p2col:{cmd:r(N_selected)}}Number selected by if/in.{p_end}
{p2col:{cmd:r(N_mapping)}}Number of validated dictionary entries.{p_end}
{p2col:{cmd:r(N_normalized)}}Number of nonempty raw input strings processed by harmonization, summed across input variables (see performance note).{p_end}
{p2col:{cmd:r(N_outputs)}}Number of output families.{p_end}
{p2col:{cmd:r(summary)}}Matrix: selected, eligible, matched, coded, unmatched, emptycode, multiple, rate.{p_end}
{p2col:{cmd:r(generated)}}Generated code, flag, split, and status variables.{p_end}
{p2col:{cmd:r(harmonized)}}Retained matching text variables.{p_end}
{p2col:{cmd:r(statusvars)}}Generated status variables.{p_end}
{p2col:{cmd:r(codetypes)}}First-code types, numeric or string, in output order.{p_end}
{p2col:{cmd:r(codevars)}}Requested dictionary code columns.{p_end}
{p2col:{cmd:r(suffixes)}}The three output suffixes.{p_end}
{p2col:{cmd:r(unmatched)}}Report filename, if requested.{p_end}
{p2colreset}{...}

{pstd}
Eligible means selected with at least one nonmissing matching key. Matched counts
dictionary hits regardless of empty codes. Coded counts assigned nonempty
codes, including explicit string missing codes. Unmatched = eligible - matched.
Emptycode = matched - coded. Rate = coded / eligible (0-1), or missing with
zero eligible observations. Multiple counts lists with two or more components.

{title:Executable example}

{pstd}The following creates artificial mapping and input data:{p_end}
{cmd}
    clear
    input str30 text str12 countrycode
    "DEUTSCHLAND" "276"
    "FRANKREICH"  "250"
    "ZWEI LAENDER" "276, 250"
    end
    tempfile countries
    save "`countries'"

    clear
    input str30 response
    " deutschland "
    "FRANKREICH"
    "Zwei Laender"
    "Unbekannt"
    ""
    end
    stringtocode response, using("`countries'") key(text) code(countrycode) ///
        keepharm status splitcodes
    list
    return list
{txt}

{pstd}Alternative suffixes on a fresh input dataset:{p_end}
{phang2}{cmd:stringtocode response, using("mapping.dta") key(text) code(code) suffixes(_codes _first _multi) keepharm harmsuffix(_clean)}

{pstd}Composite key and multiple code columns:{p_end}
{phang2}{cmd:stringtocode university city, using("universities.dta") key(name location) code(university_code city_code) multistring multicode status}

{title:Error handling and compatibility}

{pstd}
The command preserves the original in-memory dataset until processing
succeeds. Errors and Break restore it; internal frames and variables are
temporary. The unmatched report is written only after coding succeeds, and
only its file can be replaced. Do not use filesystem aliases (symlinks or hard
links) to point unmatched() at the mapping file or another protected file.

{pstd}
Compared with the original version: output suffixes and the three modes remain;
if/in now work; only input responses are harmonized; project substitutions require the explicit projectharm option and
implicit -999 copying is removed; duplicate mapping keys, missing single keys and malformed
lists are errors; numeric/string codes and diagnostics are explicit. Review
existing mapping tables before migrating production workflows. Version 2.0.1
removes the temporary dictionary-key normalization introduced in 2.0.0.
No version writes these internal transformations back to the original mapping file.

{title:Author and version}

{pstd}
David Nika, German Centre for Higher Education Research and Science Studies
(DZHW), Hannover. {browse "mailto:nika@dzhw.eu":nika@dzhw.eu}.
Version 2.1.5, 11 November 2026. See the accompanying test do-file and changelog
for validation status and release notes.

{title:Performance note}

{pstd}
Version 2.1.0 reads and prepares the dictionary once per command. Each input
variable is processed in a narrow working frame. Repeated raw strings are
harmonized once per distinct value within that variable, then linked back to
observations. HTML decoding runs only on strings containing entity markers;
ASCII-only strings skip the Unicode transliteration steps. The caller's wide
dataset is not repeatedly merged or sorted. Optional split-code and status
arrays are built only when requested.

{pstd}
Raw strL values longer than 2045 bytes use an observation-level fallback, so
long inputs that shrink during harmonization remain supported. In this case
{cmd:r(N_normalized)} counts nonempty observations for that variable. With
{cmd:noharm}, its contribution is zero. Mapping key values are never harmonized.
Code-type selection still uses only matched codes for each output variable.
Runtime gains depend on the number of repeated strings and dataset width;
no measured speedup is claimed. The accompanying benchmark do-file generates
synthetic data for timing in Stata.

{title:Installation, citation, and validation}

{pstd}
Unzip the distribution, then install from its directory using
{cmd:net install stringtocode, from("/absolute/path/to/stringtocode") replace}.
See README.md for GitHub installation and the complete example do-file.

{pstd}
Suggested citation: Nika, D. (2026). stringtocode: Stata module for mapping open-ended responses to codes (Version 2.1.5) [Computer software].
CITATION.cff contains machine-readable citation metadata.
Repository: {browse "https://github.com/DavNika/stringtocode":github.com/DavNika/stringtocode}.

{pstd}
Install from GitHub:
{cmd:net install stringtocode, from("https://raw.githubusercontent.com/DavNika/stringtocode/main") replace}.

{pstd}
The author confirmed successful testing of version 2.1.5 under Stata 18 on
11 November 2026. Earlier validation also included all 24 test groups, the
benchmark, and project-data checks. Other Stata versions have not been tested.
See VALIDATION.md for details and reproduction commands.

{title:License}

{pstd}
MIT License. Copyright (c) 2026 David Nika. See LICENSE in the distribution.
