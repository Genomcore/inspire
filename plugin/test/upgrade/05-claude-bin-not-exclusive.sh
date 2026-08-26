#!/usr/bin/env bash
# .claude/bin & .claude/hooks are not INSPIRE-exclusive.
# Moved from test-upgrade.sh:149-191.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

# ---- fix round 1: .claude/bin & .claude/hooks are not INSPIRE-exclusive ---
# `.claude/bin`/`.claude/hooks` are ordinary Claude Code locations an operator
# may legitimately keep their own content in — including, after an INSPIRE-
# performed 0.3.0 hop, leftover foreign entries the hop deliberately never
# touches (it only ever removes entries IT owns). Neither may appear in a
# signature's must_not_exist list; the KB root plus the INSPIRE-exclusive
# .claude/inspire/hooks namespace are the only safe discriminators. This
# section is permanent regression coverage for that finding.

# Direction: a 0.3 fixture must also FAIL the pre-0.3 signature.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "0.3.1 tree fails the pre-0.3 signature" "$?" "1"

# The regression itself: operator-owned content under .claude/bin and
# .claude/hooks on an otherwise-clean 0.3 tree must not flip the outcome.
mkdir -p "$p/.claude/hooks" "$p/.claude/bin"
printf '#!/usr/bin/env bash\necho mine\n' > "$p/.claude/hooks/my-own-hook.sh"
printf '#!/usr/bin/env bash\necho mine\n' > "$p/.claude/bin/my-tool.sh"
verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.3 tree with operator's own .claude/hooks and .claude/bin still passes 0.3" "$?" "0"

# Half-migrated the other direction: both KB roots present, checked against
# the 0.3 signature this time — must also be refused as ambiguous, naming
# the offending path.
mkdir -p "$p/.inspire_kb"
out="$(verify_layout "$PLUGIN_ROOT" "$p" 0.3 2>&1)"; rc=$?
eq "half-migrated tree is refused against the 0.3 signature too" "$rc" "1"
check "0.3-side refusal explains the ambiguity" \
  "printf '%s' \"\$out\" | grep -qi 'inspire_kb'"
fixture_cleanup "$w"

# Structure-not-content, as a permanent assertion rather than a one-off
# manual demonstration: a deleted validator, an edited skill file, and an
# entire removed skill directory must never affect the outcome.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
rm -f "$p/.claude/bin/no-todos.sh"
printf '\nOPERATOR CUSTOMIZATION\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
rm -rf "$p/.claude/skills/inspire-spike"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "deleted validator, edited skill, removed skill dir still pass pre-0.3" "$?" "0"
fixture_cleanup "$w"

summary
