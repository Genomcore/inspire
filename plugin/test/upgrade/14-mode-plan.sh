#!/usr/bin/env bash
# --mode plan.
# Moved from test-upgrade.sh:1090-1130.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

# ---- --mode plan --------------------------------------------------------
MZ="$PLUGIN_ROOT/scripts/materialize.sh"
target="$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
before="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
out="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>/dev/null)"
rc=$?
after="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"

eq "plan exits 0"                "$rc" "0"
eq "plan wrote nothing"          "$before" "$after"
eq "plan detected 0.2.1"         "$(printf '%s' "$out" | jq -r .source_version)" "0.2.1"
eq "plan targets the plugin"     "$(printf '%s' "$out" | jq -r .target_version)" "$target"
eq "plan names the pre-0.3 layout" "$(printf '%s' "$out" | jq -r .layout)" "pre-0.3"
check "plan lists the 0.3.0 hop" \
  "[ \"\$(printf '%s' \"\$out\" | jq -r '.chain|index(\"0.3.0\")')\" != null ]"
check "plan counts verdicts" \
  "[ \"\$(printf '%s' \"\$out\" | jq -r '.verdicts.replace')\" -ge 0 ]"
# The counts are a tally over the MERGED stream (hop journal + verdicts), not
# verdicts alone: on this pre-0.3 fixture the 0.3.0 hop journals 114 bin/test
# deletions in record mode, which classify alone could never produce. This pins
# "the JSON agrees with the stderr footer" with no 0.7.0 hop needed.
check "plan's delete count includes the hop journal (>= 114)" \
  "[ \"\$(printf '%s' \"\$out\" | jq -r '.verdicts.delete')\" -ge 114 ]"
fixture_cleanup "$w"

# A pre-0.3 project must no longer be refused.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "pre-0.3 is planned, not refused" "$?" "0"
fixture_cleanup "$w"

# Never downgrade.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
fake="$(mktemp -d)"; cp -R "$PLUGIN_ROOT/." "$fake/plugin"
jq '.version="0.1.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" > "$fake/plugin/.claude-plugin/plugin.json"
bash "$MZ" --mode plan --plugin-root "$fake/plugin" --project-root "$p" >/dev/null 2>&1
eq "a downgrade is refused" "$?" "1"
rm -rf "$fake"; fixture_cleanup "$w"

summary
