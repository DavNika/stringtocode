# Validation record

## Author testing

On 11 November 2026, the author confirmed that version 2.1.5 was tested under
Stata 18 and works successfully. Earlier validation included successful runs
of all 24 corrected test groups, the benchmark, and checks with project data.
Exact Stata edition/update level was not recorded here. Other Stata versions
have not been tested. No project data or respondent-level logs are distributed.

The final documentation update adopts the MIT license, updates the title and
repository links, and records this confirmation. It does not change the tested
ado implementation, example, test suite, or benchmark.

## Reproducing the checks

Start a fresh Stata 18 session and change to the extracted repository folder:

```stata
net install stringtocode, from("C:/absolute/path/to/stringtocode") replace
which stringtocode
help stringtocode
do stringtocode_example.do
do stringtocode_tests.do "."
do stringtocode_benchmark.do 10000 50
```

Replace the local installation path with your actual absolute path. `which`
should identify version 2.1.5. Expected-error messages from negative tests are
normal; the suite must reach its final success message. The scripts restore
input data. The benchmark uses and clears timer 99.

## Distribution checks

The preparation environment checked the package file list, citation YAML,
version consistency, and ZIP integrity. It did not execute Stata; runtime
validation above is reported by the author.

Installation from the public GitHub URL can be checked once the repository
is uploaded. This remote installation was not part of the confirmed local test.
