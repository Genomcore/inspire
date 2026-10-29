#!/usr/bin/env bash
# The commit hooks, routed through dispatch.sh as Claude Code invokes it: the KB
# review after a commit, on the files that commit contains, in every layer.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
FIXTURES="$PLUGIN_ROOT/base/bin/test/fixtures"
. "$HERE/lib/assert.sh"

proj="$(mktemp -d)/proj"
mkdir -p "$proj/.inspire" "$proj/.claude/inspire"
cp -R "$PLUGIN_ROOT/base/bin" "$proj/.inspire/bin"
rm -rf "$proj/.inspire/bin/test"
cp -R "$PLUGIN_ROOT/base/hooks" "$proj/.claude/inspire/hooks"
chmod +x "$proj/.claude/inspire/hooks/"*.sh "$proj/.inspire/bin/"*.sh
( cd "$proj" && git init -q && git config user.email t@example.com && git config user.name t \
  && git commit -q --allow-empty -m root )

hook() {
  local event="$1" command="$2"
  jq -nc --arg e "$event" --arg c "$command" '{hook_event_name:$e, tool_input:{command:$c}}' \
    | ( cd "$proj" && CLAUDE_PROJECT_DIR="$proj" "$proj/.claude/inspire/hooks/dispatch.sh" )
}

commit_file() {
  local src="$1" dest="$2"
  mkdir -p "$proj/$(dirname "$dest")"
  cp "$src" "$proj/$dest"
  ( cd "$proj" && git add "$dest" && git commit -q -m "add $dest" )
}

prose_feature="inspire_kb/03_features/auth/FEAT-01-login.md"
broken_feature="inspire_kb/03_features/billing/FEAT-02-pay.md"

premise "the broken feature fixture still lacks required sections" \
  "! grep -q '^## Postconditions' '$FIXTURES/sections-present/feature-missing-section/spec/kb/03_features/auth/FEAT-01-login.md'"

commit_file "$FIXTURES/sections-present/feature-missing-section/spec/kb/03_features/auth/FEAT-01-login.md" "$broken_feature"
hook PostToolUse "git commit -m 'add billing'" 2>/dev/null >/dev/null
eq "a committed feature with errors is reported (exit 2)" "$?" "2"
err="$(hook PostToolUse "git commit -m 'add billing'" 2>&1 >/dev/null)"
has "the report names the committed file" "$err" "$broken_feature"
has "the report carries the rule" "$err" "sections-present"
has "the report says the commit went through" "$err" "the commit went through"

commit_file "$FIXTURES/prose-style/feature-flat-warning/spec/kb/03_features/auth/FEAT-01-login.md" "$prose_feature"
err="$(hook PostToolUse "git commit -m 'add login'" 2>&1 >/dev/null)"
code="$(hook PostToolUse "git commit -m 'add login'" >/dev/null 2>&1; echo $?)"
eq "prose warnings outside 04_domain reach the agent (exit 2)" "$code" "2"
has "the R2 warning is reported" "$err" "R2 sentence length"
has "the R6 warning is reported" "$err" "R6 historical language"
hasnt "a file the commit does not contain is not reported" "$err" "$broken_feature"

err="$(hook PreToolUse "git commit -m 'add login'" 2>&1 >/dev/null)"
code="$(hook PreToolUse "git commit -m 'add login'" >/dev/null 2>&1; echo $?)"
eq "the same command before it runs never blocks on a feature file" "$code" "0"
hasnt "and runs no post-commit review" "$err" "post-commit"

( cd "$proj" && printf 'notes\n' > notes.txt && git add notes.txt && git commit -q -m notes )
code="$(hook PostToolUse "git commit -m notes" >/dev/null 2>&1; echo $?)"
eq "a commit with no KB file reports nothing" "$code" "0"

( cd "$proj" && git rm -q "$prose_feature" && git commit -q -m "drop login" )
code="$(hook PostToolUse "git commit -m 'drop login'" >/dev/null 2>&1; echo $?)"
eq "a commit that only deletes a KB file reports nothing" "$code" "0"

code="$(hook PostToolUse "git status" >/dev/null 2>&1; echo $?)"
eq "another command after it runs is not routed" "$code" "0"

summary
