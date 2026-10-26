#!/usr/bin/env bash
# The 0.13.0 hop: stack profiles become skills, and an edited one keeps its edits.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

MZ="$PLUGIN_ROOT/scripts/materialize.sh"
base="$PLUGIN_ROOT/base/skills"
old=".claude/skills/inspire-code/profiles"
nest=".claude/skills/inspire-code-nestjs"
react=".claude/skills/inspire-code-react"

# edited_project <work dir> — a 0.12.0 project with three kinds of profile file:
# an edited profile, an edited reference this release did not change, and a
# profile the operator authored. react is left pristine.
edited_project() {
  local p
  # The tag is spelled out: run.sh greps these call sites for what to pre-build.
  p="$(fixture_from_tag v0.12.0 "$1" "$REPO")"
  printf '\nMY BINDINGS\n' >> "$p/$old/nestjs.md"
  printf '\nMY ASSERTIONS\n' >> "$p/$old/nestjs/references/db-assertions.md"
  printf -- '---\nkind: inspire-code-profile\nid: mystack\n---\nMINE\n' > "$p/$old/mystack.md"
  printf '%s' "$p"
}

w="$(mktemp -d)"; p="$(edited_project "$w")"
premise "the v0.12.0 baseline built" "[ -f '$p/.inspire.lock' ] && [ -f '$p/$old/nestjs.md' ]"
premise "the reference moved is one this release did not change" \
  "git -C '$REPO' show v0.12.0:plugin/base/skills/inspire-code/profiles/nestjs/references/db-assertions.md \
     | cmp -s - '$base/inspire-code-nestjs/references/db-assertions.md'"

plan="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>/dev/null)"
check "plan: the edited profile is asked about at its new path" \
  "printf '%s' '$plan' | jq -e --arg p '$nest/SKILL.md' '.ask | index(\$p)' >/dev/null"
check "plan: the edited reference nobody else changed is not asked about" \
  "printf '%s' '$plan' | jq -e --arg p '$nest/references/db-assertions.md' '.ask | index(\$p) | not' >/dev/null"
check "plan: writes nothing — the profile is still at its old path" "[ -f '$p/$old/nestjs.md' ]"

bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "update: the lock reads the new version" \
   "$(jq -r .inspire_version "$p/.inspire.lock")" \
   "$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")"
check "unanswered: the edited profile moved to its skill with the edit" \
  "grep -qx 'MY BINDINGS' '$p/$nest/SKILL.md'"
check "unanswered: and left its old path" "[ ! -e '$p/$old/nestjs.md' ]"
check "the edited reference moved with its edit" \
  "grep -qx 'MY ASSERTIONS' '$p/$nest/references/db-assertions.md'"
check "a pristine profile became the shipped skill" \
  "cmp -s '$p/$react/SKILL.md' '$base/inspire-code-react/SKILL.md'"
check "and its pristine reference too" \
  "cmp -s '$p/$react/references/testing.md' '$base/inspire-code-react/references/testing.md'"
check "a pristine reference of the edited profile arrived as shipped" \
  "cmp -s '$p/$nest/references/testing.md' '$base/inspire-code-nestjs/references/testing.md'"
check "the old skill's own SKILL.md is gone" "[ ! -e '$p/.claude/skills/inspire-code/SKILL.md' ]"
check "the old role doctrine is gone" "[ ! -e '$p/.claude/skills/inspire-code/references/roles' ]"
eq "the operator's own profile is untouched" \
   "$(tail -n 1 "$p/$old/mystack.md")" "MINE"
fixture_cleanup "$w"

# --take-base: the shipped skill wins, and the edit survives where it was.
w2="$(mktemp -d)"; p2="$(edited_project "$w2")"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p2" \
     --take-base "$nest/SKILL.md" >/dev/null 2>"$w2/err"
check "--take-base: the skill is the shipped one" \
  "cmp -s '$p2/$nest/SKILL.md' '$base/inspire-code-nestjs/SKILL.md'"
check "--take-base: the edited profile stays at its old path" \
  "grep -qx 'MY BINDINGS' '$p2/$old/nestjs.md'"
check "--take-base: the resolution matched something" \
  "! grep -q 'matched nothing' '$w2/err'"
fixture_cleanup "$w2"

# --take-mine: the explicit spelling of the default.
w3="$(mktemp -d)"; p3="$(edited_project "$w3")"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p3" \
     --take-mine "$nest/SKILL.md" >/dev/null 2>"$w3/err"
check "--take-mine: the edited profile is the skill" \
  "grep -qx 'MY BINDINGS' '$p3/$nest/SKILL.md'"
check "--take-mine: the resolution matched something" \
  "! grep -q 'matched nothing' '$w3/err'"
fixture_cleanup "$w3"

summary
