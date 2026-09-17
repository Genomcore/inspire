#!/usr/bin/env bash
# The orchestrator's per-module unit tests, one PASS/FAIL line each.
#
# Every folder under base/bin/lib/orchestrator/ carries its module and its own
# test_<module>.py; pytest runs the lot. Rendering each case as one assertion is
# what lets run.sh's inventory name them — so a case that vanishes is a label
# that vanishes, the same way a bash assertion is.
#
# pytest is a development dependency of this repo alone: it is layered onto the
# entry point's own environment with `uv run --with`, so nothing under base/
# declares it and nothing ships it.
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

# `python_functions` is narrowed to `test_*`: pytest's default `test*` also
# collects a production helper like `tests_root_args` where a test module
# imports one, and reads its arguments as fixtures it cannot supply.
( cd "$LIB" && PYTHONDONTWRITEBYTECODE=1 \
    uv run --no-project --python "$PY" --with pytest \
      python -m pytest -v -p no:cacheprovider -o python_functions='test_*' . \
) >"$TMP/out" 2>&1
rc=$?

# `-v` prints one line per case: `pkg/mod/test_mod.py::Class::test_x PASSED`.
# The node id reads as the dotted path the labels have always carried, which is
# what keeps the inventory's names stable across the runner change.
n=0
while IFS= read -r line; do
  node="${line%% *}"; status="${line#* }"; status="${status%% *}"
  case "$node" in *.py::*) ;; *) continue ;; esac
  case "$status" in PASSED|FAILED|ERROR|SKIPPED|XFAIL|XPASS) ;; *) continue ;; esac
  label="${node/.py::/::}"; label="${label//\//.}"; label="${label//::/.}"
  label="unit: ${label#orchestrator.}"
  n=$((n + 1))
  case "$status" in
    PASSED|XFAIL) ok "$label" ;;
    SKIPPED) skip "$label" ;;
    *) bad "$label ($status)" ;;
  esac
done < "$TMP/out"

check "unit: discover ran at least one case" "[ $n -gt 0 ]"
eq "unit: the suite exits clean" "$rc" "0"
[ "$rc" -eq 0 ] || tail -60 "$TMP/out"

summary
