#!/usr/bin/env bash
# The resolution flags end to end, on a pre-0.3 conflict.
# Cut from upgrade/18-e2e-0.1.0.sh:159-206 (test-upgrade.sh:1498-1545).
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/merge.sh"

base="$PLUGIN_ROOT/base"
MAP_03="$(layout_map "$PLUGIN_ROOT" 0.3)"
MAP_PRE="$(layout_map "$PLUGIN_ROOT" pre-0.3)"
MZ="$PLUGIN_ROOT/scripts/materialize.sh"
target="$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")"

# --take-base overrides a conflict.
#
# A 0.2.1 fixture again, and a SKILL: base/ is byte-identical between 0.3.0 and
# 0.3.1, so a 0.3.0 project has no stale file to build a conflict from. Skills
# also live at .claude/skills/ in both layouts, so the path the flag names is the
# same before and after the hops — which is what --take-base takes.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
v="$(mktemp)"
classify "$PLUGIN_ROOT/manifests/0.2.1.json" "$p" "$base" "$MAP_PRE" "$MAP_03" > "$v"
stale="$(awk -F'\t' '$1=="replace" && $2 ~ /^\.claude\/skills\//{print $2; exit}' "$v")"
check "found a stale skill to conflict on" "[ -n '$stale' ]"
printf '\nMY EDIT\n' >> "$p/$stale"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" \
     --take-base "$stale" >/dev/null 2>&1
src_of="skills/${stale#.claude/skills/}"
eq "--take-base installed ours" \
   "$(shasum -a 256 "$p/$stale" | awk '{print $1}')" \
   "$(shasum -a 256 "$base/$src_of" | awk '{print $1}')"

# And the default the other way: an unresolved conflict keeps theirs.
w2="$(mktemp -d)"; p2="$(fixture_from_tag v0.2.1 "$w2" "$REPO")"
printf '\nMY EDIT\n' >> "$p2/$stale"
mine2="$(shasum -a 256 "$p2/$stale" | awk '{print $1}')"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p2" >/dev/null 2>&1
eq "an unresolved conflict defaults to keeping theirs" \
   "$(shasum -a 256 "$p2/$stale" | awk '{print $1}')" "$mine2"
fixture_cleanup "$w2"

# --take-mine is the explicit spelling of that default, and --skip is its
# deprecated alias. Both must resolve the same ask row to `keep`.
w3="$(mktemp -d)"; p3="$(fixture_from_tag v0.2.1 "$w3" "$REPO")"
printf '\nMY EDIT\n' >> "$p3/$stale"
mine3="$(shasum -a 256 "$p3/$stale" | awk '{print $1}')"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p3" \
     --take-mine "$stale" >/dev/null 2>&1
eq "--take-mine keeps theirs" \
   "$(shasum -a 256 "$p3/$stale" | awk '{print $1}')" "$mine3"
fixture_cleanup "$w3"

w4="$(mktemp -d)"; p4="$(fixture_from_tag v0.2.1 "$w4" "$REPO")"
printf '\nMY EDIT\n' >> "$p4/$stale"
mine4="$(shasum -a 256 "$p4/$stale" | awk '{print $1}')"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p4" \
     --skip "$stale" >/dev/null 2>&1
eq "--skip still keeps theirs (deprecated alias)" \
   "$(shasum -a 256 "$p4/$stale" | awk '{print $1}')" "$mine4"
fixture_cleanup "$w4"
rm -f "$v"; fixture_cleanup "$w"

summary
