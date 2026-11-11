# stringtocode

**Stata module for mapping open-ended responses to codes.**
Version 2.1.5 · David Nika · DZHW

`stringtocode` harmonizes response text and assigns codes by exact lookup in a
user-supplied Stata dictionary. It supports independent response variables,
composite keys, multiple code columns, and comma-separated code lists.
It is not a fuzzy matcher or a machine-learning classifier.

## Requirements

Stata **18 or later**; tested by the author under **Stata 18**. Later versions
have not been tested. No external packages, Python, or online service are
required for coding. Installation from GitHub requires internet access.

## Installation

Download and unzip the distribution, then run (replace the example path):

```stata
net install stringtocode, from("C:/path/to/stringtocode") replace
which stringtocode
help stringtocode
```

Install from GitHub:

```stata
net install stringtocode, from("https://raw.githubusercontent.com/DavNika/stringtocode/tree/main") replace
```

For a reproducible release, replace `main` with the published tag `v2.1.5`.
Restart Stata after updating if an older version is already loaded.

## Quick start

Run `do stringtocode_example.do` from the extracted repository directory for
a complete example with synthetic data. It restores your in-memory data.
For your own input and dictionary:

```stata
stringtocode response, using("mapping.dta") key(text) code(value) keepharm status
```

The dictionary must contain `text` and `value`. Default harmonization converts
input ` München ` to `MUENCHEN`, so the dictionary key must be `MUENCHEN`.
**Dictionary keys are matched exactly as stored, never harmonized. The mapping
file and original response variables are not changed.**

| Default output | Meaning |
|---|---|
| `response_g1` | Full comma-separated code list, string |
| `response_g2` | First code; numeric automatically when conversion is safe |
| `response_f1` | Multiple-code flag (0/1 within the selected sample) |

`codetype(auto)` protects leading-zero identifiers and long numeric strings;
therefore `_g2` intentionally remains string in those cases. Use
`codetype(string)` to retain text or `codetype(numeric)` to require conversion.

## Main options

| Option | Purpose |
|---|---|
| `suffixes(_codes _first _multi)` | Custom names for the three standard outputs |
| `keepharm harmsuffix(_clean)` | Keep processed matching strings |
| `noharm` | Match original input text without harmonization |
| `projectharm` | Apply the optional project-specific substitutions described below |
| `multistring` | Match all input variables jointly, in their specified order |
| `multistring multicode` | Generate outputs for several dictionary code columns |
| `keepcode` | Retain raw dictionary code columns; requires `multistring` |
| `nogtwo` | Put the first code under `_g1`, omitting the full-list output |
| `splitcodes` | Create `_code1`, `_code2`, etc. |
| `status` | Distinguish excluded, missing-key, unmatched, coded, and empty-code rows |
| `listunmatched` | Display unmatched-key frequencies |
| `unmatched("unmatched.dta") replace` | Save unmatched-key frequencies; `replace` applies only to this file |

`if` and `in` select observations without dropping or reordering them.
Existing variables are never overwritten. Errors restore the input dataset.
See `help stringtocode` for all options, types, return values, and limits.

## Composite keys and missing values

```stata
stringtocode university city, using("universities.dta") ///
    key(name location) code(university_code city_code) multistring multicode status
```

Missing components are allowed: empty/BERLIN can match empty/BERLIN. They are
positional values, not wildcards. Rows with all components missing never match.
Without `multistring`, each input is coded separately and missing dictionary
keys are rejected. Dictionary keys (or complete composite keys) must be unique.

## Code lists

The delimiter is always a comma. `12,34,56` is valid and contains three codes.
`12,,34`, `,12`, and `12,` are invalid because a component is empty. An entirely
empty dictionary code is allowed and receives status 4 after a match.
Order and repeated codes are retained. No special treatment of `-999` is applied.

## Harmonization

Default input processing includes a finite set of HTML entities, Unicode
normalization, uppercasing, German umlaut transliteration, Latin accent removal,
and whitespace cleanup. See the help file for the exact supported characters.
It does not automatically delete ordinary plus signs, hash signs, or digits.

`projectharm` additionally removes `2C`, `3A`, `27`, and `5C` with or without
`#`, plus `PLS`, `<PLS>`, and `<PLS`, case-insensitively after uppercasing.
It deletes all remaining `#` and turns both backslash-plus and `+` into spaces.
Whitespace is then collapsed. Rules apply anywhere: `1270` becomes `10`;
`Lehrer++Berlin#2c` becomes `LEHRER BERLIN`. Enable this option only for inputs
with these known project artifacts. `noharm` overrides `projectharm`.
Mapping keys remain unchanged in every mode.

## Validation and performance

The author confirmed successful testing of version 2.1.5 under Stata 18 on
11 November 2026. Earlier validation also included all 24 test groups, the
benchmark, and project-data checks. See [VALIDATION.md](VALIDATION.md).

The dictionary is prepared once per call. Repeated response strings are
harmonized once per distinct value per variable where possible. Narrow working
frames avoid repeatedly merging the entire input dataset. No numerical speedup
claim is made; the benchmark provides reproducible synthetic workloads.

## Citation

Nika, D. (2026). *stringtocode: Stata module for mapping open-ended responses to codes* (Version 2.1.5) [Computer software].

Repository: https://github.com/DavNika/stringtocode

See [CITATION.cff](CITATION.cff). Please cite the release used in your work.

## License and contact

Released under the [MIT License](LICENSE). Copyright (c) 2026 David Nika.
Citation is requested independently of the license conditions.

David Nika, German Centre for Higher Education Research and Science Studies
(DZHW), Hannover · nika@dzhw.eu.
For bug reports, include the Stata version, command, error message, and a small
synthetic example that reproduces the problem.
