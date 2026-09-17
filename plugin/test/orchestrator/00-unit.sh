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
# Canonical on purpose: uv keys the script's environment on the path as spelled.
ORCH="$(cd -P "$HERE/../base/bin" && pwd -P)/emanate-orchestrator.py"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

premise "the orchestrator package ships its test folders" \
  "[ -n \"\$(find '$LIB/orchestrator' -name 'test_*.py' | head -1)\" ]"
premise "uv is on PATH — the entry point's PEP 723 header names its dependencies" \
  "command -v uv >/dev/null"

# The interpreter is the script's own: uv resolves the header's dependencies into
# a cached environment once, and hands back its python. `find` alone falls back
# to a bare interpreter when that environment does not exist yet, so sync first.
uv sync --script "$ORCH" -q
PY="$(uv python find --script "$ORCH")"
premise "uv resolved the script's environment" "[ -x '$PY' ]"
check "unit: the header's dependency imports in that environment" \
  "'$PY' -c 'import langgraph'"

( cd "$LIB" && PYTHONDONTWRITEBYTECODE=1 \
    "$PY" -m unittest discover -s . -t . -p 'test_*.py' -v ) >"$TMP/out" 2>&1
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
