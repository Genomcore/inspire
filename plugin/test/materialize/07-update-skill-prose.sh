#!/usr/bin/env bash
# The pair of refusals must not form a closed loop.
# Moved from test-materialize.sh:658-687.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

# ---------------------------------------------------------------------------
# THE PAIR OF REFUSALS ABOVE AND BELOW MUST NOT FORM A CLOSED LOOP. init refuses
# an unmigrated pre-0.3 tree and points at /inspire:update (asserted above);
# update/SKILL.md used to refuse when .inspire.lock was absent, telling the
# operator "this project was never initialized" and sending them to
# /inspire:init. But a pre-0.3 project may legitimately have NO lock — the
# install.sh-era installer wrote one only when both a manifest and jq were
# present, and detection works fine without one (test-upgrade.sh: "detect 0.2.1
# with no lock at all"). So the two instructions pointed at each other with no
# exit, and one of them stated something false about the operator's project.
# Prose is all that was wrong, and prose is what is asserted.
# ---------------------------------------------------------------------------
US="$PLUGIN_ROOT/skills/update/SKILL.md"
check "update skill: exists where the assertions below can see it" "[ -f '$US' ]"
# Grep a FLATTENED copy, not the file: markdown wraps, and the sentence this must
# never say again was itself split across two lines ("this project was never" /
# "initialized — direct the operator to /inspire:init"), so a line-oriented grep
# for it passed even before the fix. Whitespace-squeezed, the claim is visible
# however it is wrapped, and so is a re-worded reintroduction of it.
US_FLAT="$(mktemp)"; tr '\n' ' ' < "$US" | tr -s ' ' > "$US_FLAT"
check "update skill: never claims a missing lock means the project was never initialized" \
  "! grep -qi 'never initialized' '$US_FLAT'"
check "update skill: says the version is identified from disk" \
  "grep -qi 'from what is actually on disk' '$US_FLAT'"
check "update skill: names the legitimate no-lock pre-0.3 case" \
  "grep -qi 'may legitimately have no lock' '$US_FLAT'"
check "update skill: warns that redirecting to init is the closed loop" \
  "grep -qi 'closed loop' '$US_FLAT'"
rm -f "$US_FLAT"

summary
