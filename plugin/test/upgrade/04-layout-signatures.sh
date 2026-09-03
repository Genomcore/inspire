#!/usr/bin/env bash
# Layout signatures.
# Moved from test-upgrade.sh:116-148.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

# ---- layout signatures --------------------------------------------------
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "0.2.1 tree satisfies the pre-0.3 signature" "$?" "0"

verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.2.1 tree fails the 0.3 signature" "$?" "1"

# Half-migrated by hand: both KB roots present. We cannot tell which is live.
mkdir -p "$p/inspire_kb"
out="$(verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 2>&1)"; rc=$?
eq "half-migrated tree is refused" "$rc" "1"
check "refusal explains the ambiguity" \
  "printf '%s' \"\$out\" | grep -qi 'inspire_kb'"
fixture_cleanup "$w"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.3.1 tree satisfies the 0.3 signature" "$?" "0"
fixture_cleanup "$w"

verify_layout "$PLUGIN_ROOT" "$p" no-such-layout >/dev/null 2>&1
eq "unknown layout id is refused" "$?" "1"

eq "layout_map for pre-0.3 puts bin under .claude" \
   "$(layout_map "$PLUGIN_ROOT" pre-0.3)" \
   "bin:.claude/bin hooks:.claude/hooks skills:.claude/skills"
eq "layout_map for 0.3 puts bin under .inspire" \
   "$(layout_map "$PLUGIN_ROOT" 0.3)" \
   "bin:.inspire/bin hooks:.claude/inspire/hooks skills:.claude/skills agents:.claude/agents"
layout_map "$PLUGIN_ROOT" no-such-layout >/dev/null 2>&1
eq "layout_map refuses an unknown layout" "$?" "1"

summary
