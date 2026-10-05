#!/usr/bin/env bash
# Use the released baseline: retire untouched files, preserve local edits.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/released"
p="$(fixture_from_tag v0.9.9 "$TMP/released" "$REPO")" || exit 1
retired=(emanate-derive.sh lib/derive-{json,types,refusals,domain,screen,catalog}.sh)
for file in "${retired[@]}"; do
  premise "released fixture ships $file" "[ -f '$p/.inspire/bin/$file' ]"
done
# Exercise both the entry and a library as edited files in a second installation.
cp -Rp "$p" "$TMP/edited"
for file in emanate-derive.sh lib/derive-json.sh; do
  printf '\n# local edit\n' >> "$TMP/edited/.inspire/bin/$file"
  cp "$TMP/edited/.inspire/bin/$file" "$TMP/$(basename "$file").expected"
done
for project in "$p" "$TMP/edited"; do
  bash "$PLUGIN_ROOT/scripts/materialize.sh" --mode plan --plugin-root "$PLUGIN_ROOT" \
    --project-root "$project" > "$TMP/plan.json" 2> "$TMP/plan.err"
  eq "retirement: preview succeeds" "$?" 0
  check "retirement: preview leaves the old entry on disk" "[ -f '$project/.inspire/bin/emanate-derive.sh' ]"
  bash "$PLUGIN_ROOT/scripts/materialize.sh" --mode update --plugin-root "$PLUGIN_ROOT" \
    --project-root "$project" > "$TMP/update.json" 2> "$TMP/update.err"
  eq "retirement: update succeeds" "$?" 0
  for file in "${retired[@]}"; do
    if [ "$project" = "$TMP/edited" ] && { [ "$file" = emanate-derive.sh ] || [ "$file" = lib/derive-json.sh ]; }; then
      check "retirement: edited $file survives byte-for-byte" \
        "cmp -s '$project/.inspire/bin/$file' '$TMP/$(basename "$file").expected'"
      check "retirement: edited $file is reported" "grep -q 'no longer part of INSPIRE, but you edited it' '$TMP/update.err'"
    else
      check "retirement: untouched $file is removed" "[ ! -e '$project/.inspire/bin/$file' ]"
    fi
  done
  for file in _lib.sh _keyed-heads.sh keys-present.sh constraints-mechanics.sh \
              head-referents.sh sections-present.sh screen-coherence.sh \
              emanate-plan.sh emanate-gate.sh emanate-results.sh emanate-harvest.sh \
              lib/plan-scan.sh lib/gate-contract.sh; do
    check "retirement: shared $file survives" "[ -x '$project/.inspire/bin/$file' ]"
  done
  check "retirement: methodology skills survive" "[ -f '$project/.claude/skills/inspire-domain/SKILL.md' ]"
done
summary
