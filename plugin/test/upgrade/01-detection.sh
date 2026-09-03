#!/usr/bin/env bash
# Detection: what a project is, whatever its lock claims.
# Moved from test-upgrade.sh:43-70.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

# ---- detection ----------------------------------------------------------
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"

eq "detect 0.2.1 from a clean fixture" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

rm -f "$p/.inspire.lock"
eq "detect 0.2.1 with no lock at all" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

jq -n '{inspire_version:"0.3.1",released:"x",template_sha:"x",installed_at:"x"}' \
  > "$p/.inspire.lock"
eq "detect ignores a lying lock" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

# Local edits must not change the nomination.
printf '\nLOCAL EDIT\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
rm -f "$p/.claude/bin/no-todos.sh"
eq "detect survives operator edits and deletions" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"
fixture_cleanup "$w"

# A tree with nothing of ours in it cannot be nominated.
empty="$(mktemp -d)"; ( cd "$empty" && git init -q )
detect_version "$PLUGIN_ROOT" "$empty" >/dev/null 2>&1; rc=$?
eq "detect refuses an unrecognisable tree" "$rc" "1"
rm -rf "$empty"

summary
