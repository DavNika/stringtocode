# stringtocode 2.1.5 — 2026-11-11

- Require Stata 18; all version directives specify 18.0.
- Record the author's successful final test of 2.1.5 under Stata 18.
  Earlier validation included all 24 test groups, benchmark, and project data.
- Adopt the title "stringtocode: Stata module for mapping open-ended responses to codes".
- Adopt the MIT license, Copyright (c) 2026 David Nika.
- Complete documentation, citation metadata, example, and Stata installation files.
- Configure repository links for https://github.com/DavNika/stringtocode.
- Final metadata/documentation edits do not change the tested implementation.

Historical entries below describe the status at their respective dates.

# Log-based test correction — 2026-11-11

- User log confirms execution through groups 1–18 and an unexpected r(133)
  in group 19 caused by the test fixture's unknown dup() function.
- Replace dup() in groups 19 and 23 with Stata string multiplication.
- Add runtime group headings and notices before expected negative-test errors.
- Ado remains 2.1.4. The corrected complete suite has not been rerun here.

# Test and benchmark script correction — 2026-11-10

- Replace all inline input/end fixture blocks inside program definitions with
  set obs, generate and replace. The first input terminator had ended the
  program definition early, causing an undefined mapping path at save.
- Preserve fixture types, values, assertions and dataset restoration wrappers.
- Ado remains 2.1.4; static validation only, no Stata execution available.

# stringtocode 2.1.4 — 2026-11-10

- With projectharm, delete all remaining literal # characters after the known
  artifact sequences. Default harmonization and mapping keys remain unchanged.
- Extend regression group 24 with standalone/repeated hashes and ##2c.
- Static checks only; the 24 Stata test groups have not been executed here.

# stringtocode 2.1.3 — 2026-11-10

- Extend projectharm to remove 2C/3A/27/5C with or without #, PLS, <PLS>,
  and <PLS without a closing bracket, after uppercase conversion.
- Remove marked forms directly instead of introducing extra # or brackets.
- Treat literal backslash-plus and + as spaces, regardless of existing spaces,
  retaining the agreed plus-to-space behavior instead of conditional deletion.
- Document substring effects and add regression group 24. Static checks only;
  the 24 Stata test groups have not been executed here.

# stringtocode 2.1.2 — 2026-11-10

- Add opt-in projectharm: replace literal + with spaces and delete #2c/#2C
  from input text before final whitespace cleanup.
- Keep mapping keys and default harmonization unchanged. noharm overrides
  projectharm. Support both distinct-value normalization and long-string fallback.
- Document the option and add regression group 23. Static checks only;
  the 23 Stata test groups have not been run in this environment.

# stringtocode 2.1.1 — 2026-11-10

- Fix multistring: allow missing components in dictionary keys and include
  selected inputs with at least one nonmissing component in matching.
- Match full tuples exactly, including empty positions and numeric missing
  types; keep duplicate-tuple validation and original mapping values intact.
- Add a separate eligibility link key so all-empty and if/in-excluded inputs
  cannot obtain codes, raw codes or influence automatic type selection.
- Update status 1 and eligible denominators to mean all components missing
  and at least one component nonmissing, respectively.
- Add regression groups 21–22 and update the earlier partial-key expectation.
- Static checks only; the 22 Stata test groups have not been executed here.

# stringtocode 2.1.0 — 2026-11-09

- Prepare dictionary code lists and numeric conversion information once per call.
- Harmonize distinct raw strings per input variable, then link results back.
- Restrict HTML decoding to strings with entity markers and skip Unicode
  transliteration for ASCII-only strings.
- Use narrow working frames instead of repeated full-dataset merges.
- Use compress with nocoalesce; construct optional arrays only on request.
- Keep long raw-string fallback, transactional changes, observation order,
  unchanged mapping keys, and per-output automatic type selection.
- Add r(N_normalized), regression groups 17–20 and a synthetic timing script.
- Static checks only: the 20 Stata regression groups and timing script have
  not been executed because Stata is unavailable. No measured speedup claimed.

# stringtocode 2.0.1 — 2026-11-09

- Harmonization now applies only to input responses.
- Mapping key values remain unchanged, including in temporary frames.
- Uniqueness checks refer to the original keys and say so in error messages.
- Fixed the examples and fixtures to use prepared matching keys.
- Added test group 16: distinct original keys that would normalize identically,
  exact noharm lookups, and an unchanged dictionary file after both calls.
- The 16 Stata test groups have not been executed here (no Stata runtime).

The earlier 2.0.0 normalization changed only an in-memory working copy; it did
not overwrite the source mapping file. Historical notes below describe 2.0.0.

# stringtocode 2.0.0 — 2026-11-09

This is the revised implementation for local validation, not a claim of a
Stata-tested public release.

## Preserved

- Independent coding, composite-key coding (`multistring`), and positional
  multiple-code-column output (`multistring multicode`).
- Default `_g1` full string, `_g2` first code, `_f1` multiple-code indicator.
- `nogtwo`, `keepharm`, `keepcode`, and `noharm`.
- Comma as the fixed and only code delimiter.

## Added or corrected

- Custom output suffixes and harmonized-copy suffix.
- One normalization routine for input and mapping keys.
- Unicode-aware normalization, fixed uppercase locale, documented HTML subset.
- Numeric/string/automatic first-code conversion, leading-zero protection,
  conservative precision protection, and optional split code columns.
- Correct `if`/`in`, original observation order, transactional dataset changes,
  isolated dictionary frames, and collision-free temporary names.
- Early checks for mode, key types, output names, mapping uniqueness after
  normalization, missing mapping keys, key length, and malformed code lists.
- Optional per-output status, summary matrix and `r()` metadata.
- Optional normalized-key unmatched frequency display and .dta export.

## Deliberate behavior changes

- Removed `zofarharm` and its digit/token deletion rules.
- Removed implicit copying of responses containing `-999`.
- Mapping keys are also harmonized; existing dictionaries must be revalidated.
- Empty mapping key components are rejected; empty input components do not match.
- No `stubnames()`, configurable delimiter, or special missing-code options.
- Complete duplicate mapping entries are rejected, not silently deduplicated.
- Mapping labels/notes are not imported into the caller's dataset.

## Validation delivered

- A self-contained Stata do-file with 15 groups of regression/error tests.
- Static structural review, UTF-8 check, and entity/hex table consistency checks.
- Nine independent normalization examples checked in Python against the
  documented transformation rules. These do not execute Stata code.
- **No Stata runtime was available; the Stata tests have not been executed.**

Run the test do-file under the oldest supported Stata (16) and the production
Stata version before distribution or replacing an established coding workflow.

## License

The original `LICENSE_MIT_DRAFT.txt` supplied a proposed MIT license.
Version 2.1.5 adopts MIT and provides the final text in `LICENSE`.
It is explicitly a draft; this revision does not decide the project's rights
holder or activate a public license on the author's behalf.
