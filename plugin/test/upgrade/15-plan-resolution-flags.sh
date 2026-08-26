#!/usr/bin/env bash
# Plan and the resolution flags.
# Moved from test-upgrade.sh:1131-1161.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

MZ="$PLUGIN_ROOT/scripts/materialize.sh"

# ---- plan and the resolution flags --------------------------------------
# Plan predicts the UNRESOLVED split, so it refuses the flags rather than honour
# them in one half of the run and not the other: run_plan never calls
# _apply_resolutions, so a --take-base the classify half ignored while a hop
# consulted it would put two answers in one JSON document.
#
# The pair matters together. The arrays are legitimately EMPTY on every plan
# run, and under `set -u` on bash 3.2 a bare "${ARR[@]}" expansion of an empty
# array aborts the shell outright (the ${#ARR[@]} form the guard uses today is
# safe) — so the flagless run is asserted first, on the newest layout, as the
# standing regression guard for any future edit that touches how the arrays are
# read.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
plan_out="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>/dev/null)"
eq "plan with no resolution flags exits 0" "$?" "0"
check "plan with no resolution flags still emits its JSON" \
  "printf '%s' \"\$plan_out\" | jq -e '.ask|type==\"array\"' >/dev/null"

rej_err="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" \
             --take-base .claude/skills/inspire-domain/SKILL.md 2>&1 >/dev/null)"
eq "plan rejects --take-base (rc)" "$?" "1"
check "plan's rejection says why, and where the flag belongs" \
  "printf '%s' \"\$rej_err\" | grep -q 'UNRESOLVED' && printf '%s' \"\$rej_err\" | grep -q 'mode update --dry-run'"
bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" \
     --take-mine .claude/skills/inspire-domain/SKILL.md >/dev/null 2>&1
eq "plan rejects --take-mine too" "$?" "1"
bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" \
     --skip .claude/skills/inspire-domain/SKILL.md >/dev/null 2>&1
eq "plan rejects the deprecated --skip alias as well" "$?" "1"
fixture_cleanup "$w"

summary
