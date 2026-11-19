#!/usr/bin/env bash
# /inspire-bootstrap leaves the runtime, and a project that used it reaches
# /inspire-config's outputs through one update, with nothing asked.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

MZ="$PLUGIN_ROOT/scripts/materialize.sh"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.19.0 "$w" "$REPO")"
B=".claude/skills/inspire-bootstrap"
S="$p/inspire_kb/00_bootstrap"

# Every deletion is asserted on both sides: the fixture materialized the path,
# and the update removed it.
GONE="$B/SKILL.md
$B/references/bootstrap-identity.md
$B/references/bootstrap-review.md
$B/references/bootstrap-theme-interview.md
$B/references/bootstrap-design-system-backfill.md"
for f in $GONE; do
  check "premise: v0.19.0 materialized $f" "[ -f '$p/$f' ]"
done
check "premise: v0.19.0 wrote no spec config" "[ ! -e '$p/.inspire/config.json' ]"

# What bootstrap wrote for this project: a brownfield layout and a Spanish KB.
yq -i --front-matter=process '.source_root = "." | .prototype_root = "none"' "$S/stack.md"
yq -i --front-matter=process '.output_language = "es"' "$S/project.md"
# One bootstrap reference the operator edited.
printf '\nOUR OWN STEP\n' >> "$p/$B/references/bootstrap-stack-interview.md"
edit="$(shasum -a 256 < "$p/$B/references/bootstrap-stack-interview.md")"
stack="$(shasum -a 256 < "$S/stack.md")"; project="$(shasum -a 256 < "$S/project.md")"

out="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1)"
eq "update: a v0.19.0 project upgrades" "$?" "0"

for f in $GONE; do
  check "update: untouched $f is deleted" "[ ! -e '$p/$f' ]"
done
eq "update: the edited bootstrap reference is kept with its edit" \
   "$(shasum -a 256 < "$p/$B/references/bootstrap-stack-interview.md")" "$edit"
has "update: the report says why it stayed" "$out" "no longer part of INSPIRE, but you edited it"

# The successors arrive.
for f in inspire-config/references/wizard.md inspire-config/references/stack-interview.md \
         inspire-config/references/spec-config.md inspire-config/references/seeds.md \
         inspire-screens/references/design-system-edit.md \
         inspire-screens/references/design-system-backfill.md; do
  check "update: $f is installed" "[ -f '$p/.claude/skills/$f' ]"
done

# The spec config carries what bootstrap had recorded, and the KB is untouched.
cfg="$p/.inspire/config.json"
eq "config: source_root from stack.md"       "$(jq -r .source_root "$cfg")" "."
eq "config: prototype_root from stack.md"    "$(jq -r .prototype_root "$cfg")" "none"
eq "config: output_language from project.md" "$(jq -r .output_language "$cfg")" "es"
eq "update: stack.md is byte-identical"      "$(shasum -a 256 < "$S/stack.md")" "$stack"
eq "update: project.md is byte-identical"    "$(shasum -a 256 < "$S/project.md")" "$project"

# The session and the validators read the config from now on.
lang="$(CLAUDE_PROJECT_DIR="$p" bash "$p/.claude/inspire/hooks/session-start.sh" </dev/null \
  | jq -r '.hookSpecificOutput.additionalContext')"
has "session: starts in the project's language" "$lang" 'output_language: es'
eq "validators: read the code at the repository root" \
   "$(cd "$p" && bash -c '. .inspire/bin/_lib.sh; printf %s "$SDD_SOURCE_ROOT"')" "."

# A second update changes nothing in the config.
before="$(shasum -a 256 < "$cfg")"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "second update: the config is byte-identical" "$(shasum -a 256 < "$cfg")" "$before"

rm -rf "$w"
summary
