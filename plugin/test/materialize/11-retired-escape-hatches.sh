#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

work="$(mktemp -d)"
proj="$(fixture_from_tag v0.15.0 "$work" "$REPO")"
premise "the 0.15.0 project ships the ratchet" "[ -f '$proj/.inspire/bin/escape-hatch-ratchet.sh' ]"

config='{ "scope": ["source/src"], "extensions": ["ts"], "patterns": [{ "id": "as-any", "regex": "as any", "ceiling": 0 }] }'
printf '%s\n' "$config" > "$proj/.escape-hatches.json"

dry="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" --dry-run 2>/dev/null)"
check "a dry run warns about .escape-hatches.json" \
  "printf '%s' \"\$dry\" | jq -r '.warnings[]' | grep -q '^.escape-hatches.json is no longer read'"

out="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" 2>/dev/null)"
check "the update warns about .escape-hatches.json" \
  "printf '%s' \"\$out\" | jq -r '.warnings[]' | grep -q '^.escape-hatches.json is no longer read'"
check "the warning points at the lint config" \
  "printf '%s' \"\$out\" | jq -r '.warnings[]' | grep -q 'no-restricted-disable'"
eq "the update leaves .escape-hatches.json as it was" "$(cat "$proj/.escape-hatches.json")" "$config"
check "the update deletes the ratchet" "[ ! -e '$proj/.inspire/bin/escape-hatch-ratchet.sh' ]"

rm -f "$proj/.escape-hatches.json"
again="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" 2>/dev/null)"
check "no warning once the file is gone" \
  "! printf '%s' \"\$again\" | jq -r '.warnings[]' | grep -q 'escape-hatches'"

premise "the project resolves the nestjs profile" \
  "yq --front-matter=extract '.profiles[]' '$proj/inspire_kb/00_bootstrap/stack.md' | grep -qx nestjs"
mkdir -p "$proj/source"
printf '%s\n' '{ "rules": { "typescript/no-explicit-any": "error" } }' > "$proj/source/.oxlintrc.json"

dry="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" --dry-run 2>/dev/null)"
check "a dry run warns that the oxlint config lacks the escape-hatch rules" \
  "printf '%s' \"\$dry\" | jq -r '.warnings[]' | grep -q '^source/.oxlintrc.json lacks the escape-hatch rules'"

out="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" 2>/dev/null)"
check "the update warns that the oxlint config lacks the escape-hatch rules" \
  "printf '%s' \"\$out\" | jq -r '.warnings[]' | grep -q '^source/.oxlintrc.json lacks the escape-hatch rules'"
check "the warning names the pre-PR hook" \
  "printf '%s' \"\$out\" | jq -r '.warnings[]' | grep 'lacks the escape-hatch rules' | grep -q 'pre-PR hook'"

printf '%s\n' '{ "jsPlugins": ["./oxlint-escape-hatches.mjs"], "rules": {
  "escape-hatches/require-reason": "error",
  "escape-hatches/no-restricted-disable": ["error", ["typescript/no-explicit-any"]],
  "escape-hatches/no-double-cast": "error" } }' > "$proj/source/.oxlintrc.json"
installed="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" 2>/dev/null)"
check "no warning once the three rules are in the oxlint config" \
  "! printf '%s' \"\$installed\" | jq -r '.warnings[]' | grep -q 'escape-hatch'"

fixture_cleanup "$work"
summary
