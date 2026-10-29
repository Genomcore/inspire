#!/usr/bin/env bash
# The in-session emanation loop leaves the runtime: /inspire-emanate, the five
# agent shells, the emanate-*.sh tools and their .inspire/bin/lib/ units.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

MZ="$PLUGIN_ROOT/scripts/materialize.sh"

# ---------------------------------------------------------------------------
# No hop removes them, and none should: the classifier already reads a file the
# source manifest lists and the plugin no longer ships as dropped upstream —
# delete it when untouched, keep it when edited, never prompt. This block pins
# that for the one removal big enough to empty two directories, so a later
# change to the classifier cannot quietly start leaving them behind.
#
# Every deletion is asserted on BOTH sides: a premise that the v0.14.0 fixture
# really materialized the path, then its absence after the upgrade. Absence
# alone would pass on a fixture that never had the file.
# ---------------------------------------------------------------------------

w="$(mktemp -d)"; p="$(fixture_from_tag v0.14.0 "$w" "$REPO")"

GONE=".claude/skills/inspire-emanate/SKILL.md
.claude/skills/_references/emanation-plan.md
.claude/skills/_references/gate-verdict.md
.claude/agents/inspire-contracter.md
.claude/agents/inspire-implementer.md
.claude/agents/inspire-security-overseer.md
.claude/agents/inspire-quality-overseer.md
.inspire/bin/emanate-derive.sh
.inspire/bin/emanate-gate.sh
.inspire/bin/emanate-results.sh
.inspire/bin/emanate-harvest.sh
.inspire/bin/lib/plan-lib.sh
.inspire/bin/lib/derive-json.sh
.inspire/bin/lib/gate-verdict.sh"

for f in $GONE; do
  check "premise: v0.14.0 materialized $f" "[ -f '$p/$f' ]"
done

# One shell and one tool edited, one agent of the operator's own.
printf '\nMY RULE\n' >> "$p/.claude/agents/inspire-tester.md"
printf '\n# my tweak\n' >> "$p/.inspire/bin/emanate-plan.sh"
mkdir -p "$p/.claude/agents"; printf 'mine\n' > "$p/.claude/agents/my-agent.md"
tester_edit="$(shasum -a 256 < "$p/.claude/agents/inspire-tester.md")"
plan_edit="$(shasum -a 256 < "$p/.inspire/bin/emanate-plan.sh")"

out="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1)"
eq "update: a v0.14.0 project upgrades" "$?" "0"

for f in $GONE; do
  check "update: untouched $f is deleted" "[ ! -e '$p/$f' ]"
done
check "update: the emptied inspire-emanate/ is pruned" \
  "[ ! -e '$p/.claude/skills/inspire-emanate' ]"

eq "update: the edited shell is kept with its edit" \
   "$(shasum -a 256 < "$p/.claude/agents/inspire-tester.md")" "$tester_edit"
eq "update: the edited tool is kept with its edit" \
   "$(shasum -a 256 < "$p/.inspire/bin/emanate-plan.sh")" "$plan_edit"
check "update: the report says why the edited files stayed" \
  "printf '%s' \"\$out\" | grep -q 'no longer part of INSPIRE, but you edited it'"
eq "update: the operator's own agent is untouched" \
   "$(cat "$p/.claude/agents/my-agent.md")" "mine"
check "update: the agents class itself survives" "[ -f '$p/.claude/agents/README.txt' ]"
check "update: no shipped skill dir is left empty" \
  "[ -z \"\$(find '$p/.claude/skills' -type d -empty)\" ]"

# With the edited tool kept, lib/ is the operator's leftover to clear; without
# it, nothing of INSPIRE's may remain there. Check the second case on a fresh
# fixture, where nothing was edited.
fixture_cleanup "$w"
w="$(mktemp -d)"; p="$(fixture_from_tag v0.14.0 "$w" "$REPO")"
check "premise: v0.14.0 materialized .inspire/bin/lib/" "[ -d '$p/.inspire/bin/lib' ]"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "update: an unedited v0.14.0 project upgrades" "$?" "0"
check "update: .inspire/bin/lib/ is pruned entirely" "[ ! -e '$p/.inspire/bin/lib' ]"
eq "update: .claude/agents/ holds only the class README" \
   "$(ls -A "$p/.claude/agents" | tr '\n' ' ')" "README.txt "
check "update: settings.json names no emanate piece" \
  "! grep -qiE 'emanate|contracter|overseer' '$p/.claude/settings.json'"
fixture_cleanup "$w"

echo ""; echo "Passed: $pass · Failed: $fail · Skipped: $skip"
[ "$fail" -eq 0 ]
