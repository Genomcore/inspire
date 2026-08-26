#!/usr/bin/env bash
# The half-migrated tree.
# Moved from test-upgrade.sh:1547-1574.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

MZ="$PLUGIN_ROOT/scripts/materialize.sh"

# ---- the half-migrated tree ---------------------------------------------
# THE gap Task 12 left open. A project that ran migration step 1 only
# (`git mv .inspire_kb inspire_kb`) and none of steps 2-6 is not caught by
# require_migrated_layout — inspire_kb/ exists, so that guard stands down —
# yet .claude/skills/ is the SAME destination in both layouts, so the old
# copy path overwrote a locally-edited shipped skill with no drift step and
# no gate. verify_layout is what closes it: the pre-0.3 signature requires
# .inspire_kb/ present and inspire_kb/ absent, and this tree is neither.
# Refusal before anything is written is the only safe answer — the two
# locations cannot be told apart, and guessing risks the live one.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
( cd "$p" && mv .inspire_kb inspire_kb )
printf '\nMY EDIT\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
half_hash="$(shasum -a 256 "$p/.claude/skills/inspire-domain/SKILL.md" | awk '{print $1}')"
half_err="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1 >/dev/null)"
eq "half-migrated tree: update refuses (rc)" "$?" "1"
check "half-migrated tree: the refusal names both KB locations" \
  "printf '%s' \"\$half_err\" | grep -q 'inspire_kb'"
eq "half-migrated tree: the edited skill is untouched" \
   "$(shasum -a 256 "$p/.claude/skills/inspire-domain/SKILL.md" | awk '{print $1}')" "$half_hash"
check "half-migrated tree: nothing was moved" \
  "[ -d '$p/.claude/bin' ] && [ ! -d '$p/.claude/inspire/hooks' ]"
check "half-migrated tree: the 0.2 hook registrations are left as they were" \
  "[ \"\$(jq '[.. | objects | select(has(\"command\")) | select(.command|contains(\".claude/hooks/\"))] | length' '$p/.claude/settings.json')\" = 3 ]"
check "half-migrated tree: no lock was rewritten" \
  "[ \"\$(jq -r .inspire_version '$p/.inspire.lock')\" = '0.2.1' ]"
fixture_cleanup "$w"

summary
