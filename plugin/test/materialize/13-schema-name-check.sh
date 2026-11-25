#!/usr/bin/env bash
# An update warns a NestJS project whose package.json does not run check-schema-names.mjs,
# which the NestJS skill gates, and stops warning once the lint script runs it.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

work="$(mktemp -d)"
proj="$(fixture_from_tag v0.15.0 "$work" "$REPO")"
premise "the project resolves the nestjs profile" \
  "yq --front-matter=extract '.profiles[]' '$proj/inspire_kb/00_bootstrap/stack.md' | grep -x >/dev/null nestjs"
mkdir -p "$proj/source"
printf '%s\n' '{ "scripts": { "lint": "oxlint" } }' > "$proj/source/package.json"

dry="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" --dry-run 2>/dev/null)"
check "a dry run warns that package.json does not run the schema-name check" \
  "printf '%s' \"\$dry\" | jq -r '.warnings[]' | grep >/dev/null '^source/package.json does not run check-schema-names.mjs'"

out="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" 2>/dev/null)"
check "the update warns that package.json does not run the schema-name check" \
  "printf '%s' \"\$out\" | jq -r '.warnings[]' | grep >/dev/null '^source/package.json does not run check-schema-names.mjs'"
check "the warning names where to copy it from" \
  "printf '%s' \"\$out\" | jq -r '.warnings[]' | grep 'does not run check-schema-names.mjs' | grep >/dev/null 'inspire-code-nestjs/references/'"
check "the update copies the check into the skill" \
  "[ -f '$proj/.claude/skills/inspire-code-nestjs/references/check-schema-names.mjs' ]"

printf '%s\n' '{ "scripts": { "lint": "oxlint && node check-schema-names.mjs" } }' > "$proj/source/package.json"
installed="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" 2>/dev/null)"
check "no warning once the lint script runs the check" \
  "! printf '%s' \"\$installed\" | jq -r '.warnings[]' | grep >/dev/null 'check-schema-names'"

fixture_cleanup "$work"
summary
