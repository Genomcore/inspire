#!/usr/bin/env bash
# The orchestrator's per-module unit tests, one PASS/FAIL line each.
#
# Every folder under base/bin/lib/orchestrator/ carries its module and its own
# test_<module>.py; `unittest discover` runs the lot. Rendering each case as one
# assertion is what lets run.sh's inventory name them — so a case that vanishes
# is a label that vanishes, the same way a bash assertion is.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
. "$HERE/lib/assert.sh"
LIB="$HERE/../base/bin/lib"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

premise "the orchestrator package ships its test folders" \
  "[ -n \"\$(find '$LIB/orchestrator' -name 'test_*.py' | head -1)\" ]"

( cd "$LIB" && PYTHONDONTWRITEBYTECODE=1 \
    python3 -m unittest discover -s . -t . -p 'test_*.py' -v ) >"$TMP/out" 2>&1
rc=$?

# `-v` prints one line per case: `test_x (pkg.mod.Class) ... ok` on 3.9, and
# `test_x (pkg.mod.Class.test_x) ... ok` from 3.11. Both read the same here.
n=0
while IFS= read -r line; do
  case "$line" in
    test_*" ... "*) ;;
    *) continue ;;
  esac
  name="${line%% (*}"; rest="${line#*(}"; where="${rest%%)*}"; status="${line##* ... }"
  case "$where" in *".$name") label="$where" ;; *) label="$where.$name" ;; esac
  label="unit: ${label#orchestrator.}"
  n=$((n + 1))
  case "$status" in
    ok) ok "$label" ;;
    skipped*) skip "$label" ;;
    *) bad "$label ($status)" ;;
  esac
done < "$TMP/out"

check "unit: discover ran at least one case" "[ $n -gt 0 ]"
eq "unit: the suite exits clean" "$rc" "0"
[ "$rc" -eq 0 ] || sed -n '/^=\{20,\}/,$p' "$TMP/out" | head -60

summary
