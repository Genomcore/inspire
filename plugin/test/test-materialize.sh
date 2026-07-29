#!/usr/bin/env bash
# Tests plugin/scripts/materialize.sh against a scratch project.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
PLUGIN_ROOT="$HERE/.."
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
pass=0; fail=0
ok()   { echo "PASS $1"; pass=$((pass+1)); }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

proj="$(mktemp -d)/proj"; mkdir -p "$proj"
( cd "$proj" && git init -q )

# Pre-existing user content that must survive — the regression this replaces.
mkdir -p "$proj/.claude/skills/my-own-skill"
printf -- '---\ndescription: mine\n---\nbody\n' > "$proj/.claude/skills/my-own-skill/SKILL.md"
printf '{"permissions":{"allow":["Bash(ls:*)"]}}\n' > "$proj/.claude/settings.json"

out="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
        --source-root source --prototype-root prototype --declare-marketplace 2>/dev/null)"

check "emits parseable JSON"          "printf '%s' \"\$out\" | jq -e . >/dev/null"
check "reports mode init"             "[ \"\$(printf '%s' \"\$out\" | jq -r .mode)\" = init ]"
check "kb materialized"               "[ -d '$proj/inspire_kb/00_bootstrap' ]"
check "validators materialized"       "[ -x '$proj/.inspire/bin/review.sh' ]"
check "test/ EXCLUDED"                "[ ! -e '$proj/.inspire/bin/test' ]"
check "dispatcher materialized"       "[ -x '$proj/.claude/inspire/hooks/dispatch.sh' ]"
check "skills materialized"           "[ -d '$proj/.claude/skills/inspire-domain' ]"
check "shared _references present"    "[ -d '$proj/.claude/skills/_references' ]"
check "USER SKILL PRESERVED"          "[ -f '$proj/.claude/skills/my-own-skill/SKILL.md' ]"
check "FOREIGN SETTINGS PRESERVED"    "jq -e '.permissions.allow[0]' '$proj/.claude/settings.json' >/dev/null"
check "marker present"                "grep -q INSPIRE-MANAGED '$proj/.claude/settings.json'"
check "one PreToolUse command"        "[ \"\$(jq '[.hooks.PreToolUse[].hooks[]]|length' '$proj/.claude/settings.json')\" = 1 ]"
check "marketplace declared"          "jq -e '.extraKnownMarketplaces.inspire' '$proj/.claude/settings.json' >/dev/null"
check "settings still parses"         "jq -e . '$proj/.claude/settings.json' >/dev/null"
check "lock version 0.3.0"            "[ \"\$(jq -r .inspire_version '$proj/.inspire.lock')\" = 0.3.0 ]"
check "lock has file hashes"          "jq -e '.files|length>0' '$proj/.inspire.lock' >/dev/null"
check "design system seeded"          "[ -f '$proj/inspire_kb/05_screens/design-system.md' ]"
check "product roots created"         "[ -d '$proj/source' ] && [ -d '$proj/prototype' ]"
check "no template hook leaked"       "[ -z \"\$(find '$proj/.claude' -name 'template-*.sh')\" ]"

# Idempotency: a second init must not duplicate the settings block.
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "idempotent PreToolUse"         "[ \"\$(jq '[.hooks.PreToolUse[].hooks[]]|length' '$proj/.claude/settings.json')\" = 1 ]"
check "idempotent foreign key"        "jq -e '.permissions.allow[0]' '$proj/.claude/settings.json' >/dev/null"

# drift-check classifies against the lock and writes nothing.
# Must run BEFORE the --skip test below: an update with --skip rebaselines the lock to
# the drifted hash, after which drift-check would correctly report it as unchanged.
drift="$proj/.claude/skills/inspire-domain/SKILL.md"
printf '\nLOCAL EDIT\n' >> "$drift"
rm -f "$proj/.inspire/bin/no-todos.sh"
lock_before="$(shasum -a 256 "$proj/.inspire.lock" | cut -d' ' -f1)"
dc="$("$SCRIPT" --mode drift-check --plugin-root "$PLUGIN_ROOT" --project-root "$proj" 2>/dev/null)"
lock_after="$(shasum -a 256 "$proj/.inspire.lock" | cut -d' ' -f1)"
check "drift-check parses"             "printf '%s' \"\$dc\" | jq -e . >/dev/null"
check "drift-check finds the edit"     "printf '%s' \"\$dc\" | jq -e '.drifted|index(\".claude/skills/inspire-domain/SKILL.md\")' >/dev/null"
check "drift-check finds the deletion" "printf '%s' \"\$dc\" | jq -e '.missing|index(\".inspire/bin/no-todos.sh\")' >/dev/null"
check "drift-check lists unchanged"    "[ \"\$(printf '%s' \"\$dc\" | jq '.unchanged|length')\" -gt 0 ]"
check "drift-check is read-only"       "[ '$lock_before' = \"\$lock_after\" ]"
# Restore the deleted validator so the --skip test below starts from a known state.
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype \
  --skip .claude/skills/inspire-domain/SKILL.md >/dev/null 2>&1
check "missing file restored"          "[ -x '$proj/.inspire/bin/no-todos.sh' ]"

# --skip must not overwrite a drifted file.
before="$(shasum -a 256 "$drift" | cut -d' ' -f1)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype \
  --skip .claude/skills/inspire-domain/SKILL.md >/dev/null 2>&1
after="$(shasum -a 256 "$drift" | cut -d' ' -f1)"
check "SKIPPED FILE UNTOUCHED"        "[ '$before' = '$after' ]"

# --dry-run writes nothing.
clean="$(mktemp -d)/p2"; mkdir -p "$clean"; ( cd "$clean" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$clean" \
  --source-root source --prototype-root prototype --dry-run >/dev/null 2>&1
check "dry-run writes nothing"        "[ ! -e '$clean/inspire_kb' ] && [ ! -e '$clean/.inspire.lock' ]"

# Brownfield: '.' and 'none' create no folders.
bf="$(mktemp -d)/p3"; mkdir -p "$bf"; ( cd "$bf" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$bf" \
  --source-root . --prototype-root none >/dev/null 2>&1
check "brownfield creates no source/" "[ ! -e '$bf/source' ] && [ ! -e '$bf/prototype' ]"
check "brownfield still gets kb"      "[ -d '$bf/inspire_kb/00_bootstrap' ]"

rm -rf "$(dirname "$proj")" "$(dirname "$clean")" "$(dirname "$bf")"
echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
