#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$HERE/../scripts/lib/common.sh"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

eq "equal"            "$(version_cmp 0.3.1 0.3.1)"   "0"
eq "patch older"      "$(version_cmp 0.3.0 0.3.1)"   "-1"
eq "patch newer"      "$(version_cmp 0.3.1 0.3.0)"   "1"
eq "minor dominates"  "$(version_cmp 0.2.9 0.3.0)"   "-1"
eq "major dominates"  "$(version_cmp 0.9.9 1.0.0)"   "-1"
eq "double digits"    "$(version_cmp 0.10.0 0.9.0)"  "1"
eq "short vs long"    "$(version_cmp 0.3 0.3.0)"     "0"
eq "missing patch"    "$(version_cmp 0.4 0.3.9)"     "1"

# Regressions found in review: leading zeros previously fell into bash's
# octal parsing of $((...)) (crashing on 8/9 digits, miscomputing otherwise),
# and only the first 3 components were ever compared.
eq "leading zero, same value"   "$(version_cmp 1.09.0 1.9.0)"    "0"
eq "leading zero, real diff"    "$(version_cmp 1.010.0 1.9.0)"   "1"
eq "4th component, older"       "$(version_cmp 1.2.3.4 1.2.3.5)" "-1"
eq "4th component, newer"       "$(version_cmp 1.2.3.5 1.2.3.4)" "1"

tmp="$(mktemp)"; printf 'abc' > "$tmp"
eq "sha256_of" "$(sha256_of "$tmp")" \
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
rm -f "$tmp"

eq "arr_to_json empty" "$(arr_to_json)" "[]"
eq "arr_to_json two"   "$(arr_to_json a b | jq -c .)" '["a","b"]'

echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
