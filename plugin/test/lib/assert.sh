#!/usr/bin/env bash
# The assertion vocabulary every file under plugin/test/ sources.
# The strings printed here ARE the inventory that proves a move lost nothing:
# reword one and a label that has existed since 0.2 silently disappears.

pass=0; fail=0; skip=0

ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# A block that cannot run must not masquerade as coverage: count the assertions
# it would have made and surface them in the summary, so an environment where it
# never runs (CI as root, where chmod 555 does not bite) shows the gap instead of
# reading all-green. skipped <n> <why>.
skipped(){ echo "SKIP $2 ($1 assertions)"; skip=$((skip+$1)); }
skip(){ skipped 1 "$1"; }

has(){   case "$2" in *"$3"*) ok "$1";; *) bad "$1 (got '$2', want to contain '$3')";; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (got '$2', want NOT to contain '$3')";; *) ok "$1";; esac; }

# The source-side check that keeps the assertion after it from passing vacuously;
# the prefix is what makes them countable across a whole run.
premise(){ check "premise: $1" "$2"; }

# Zero assertions is a failure: a file that made none did not run.
summary(){
  echo ""; echo "Passed: $pass · Failed: $fail · Skipped: $skip"
  [ "$fail" -eq 0 ] || exit 1
  [ $((pass + fail + skip)) -gt 0 ] || exit 1
  exit 0
}
