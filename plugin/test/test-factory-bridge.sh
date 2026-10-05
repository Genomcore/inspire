#!/usr/bin/env bash
# The planner's factory boundary: no engine here, only argv/env/stdout/status.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$HERE/lib/assert.sh"
. "$HERE/../base/bin/lib/plan-scan.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/target project" "$TMP/factory checkout/orchestrator/src" "$TMP/bin" "$TMP/c"
: > "$TMP/factory checkout/orchestrator/src/derive.ts"
cat > "$TMP/bin/bun" <<'BUN'
#!/bin/bash
printf '%s\n' "$PWD" "$SDD_KB_ROOT" "$SDD_SPEC_ROOT" "$@" > "$FACTORY_TEST_ARGS"
printf '{"schema":"inspire.derived-contract/1","unit":{"id":"auth.user"}}\n'
echo 'human report is not JSON' >&2
exit "$FACTORY_TEST_CODE"
BUN
chmod +x "$TMP/bin/bun"
cd "$TMP/target project" || exit 1
export PATH="$TMP/bin:$PATH" SDD_KB_ROOT='custom kb' SDD_SPEC_ROOT='separate domain'
export FACTORY_TEST_ARGS="$TMP/args" FACTORY_TEST_CODE=0
export INSPIRE_FACTORY_ROOT='../factory checkout'
PLAN_TMP="$TMP"
plan_require_deriver
eq "factory bridge: a relative checkout with spaces resolves" "$?" 0
plan_derive_one 1 action 'separate domain/a path.md'
eq "factory bridge: stdout is unmodified JSON, stderr stays out" "$(cat "$TMP/c/1.json")" \
  '{"schema":"inspire.derived-contract/1","unit":{"id":"auth.user"}}'
eq "factory bridge: target CWD, both roots and exact argv survive" "$(cat "$TMP/args")" \
  "$(printf '%s\n' "$PWD" 'custom kb' 'separate domain' run '../factory checkout/orchestrator/src/derive.ts' action --file 'separate domain/a path.md')"
for code in 0 1 2 3 4 5 127; do
  export FACTORY_TEST_CODE="$code"
  plan_derive_one 1 entity 'separate domain/auth.user.md'
  eq "factory bridge: preserves derive exit $code" "$(cat "$TMP/c/1.code")" "$code"
done
INSPIRE_FACTORY_ROOT='' plan_require_deriver > "$TMP/out" 2> "$TMP/err"
eq "factory bridge: unset configuration is a missing dependency" "$?" 127
check "factory bridge: unset configuration names the setting" "grep -q INSPIRE_FACTORY_ROOT '$TMP/err'"
eq "factory bridge: dependency error leaves stdout empty" "$(cat "$TMP/out")" ''
INSPIRE_FACTORY_ROOT="$TMP/old factory" plan_require_deriver > "$TMP/out" 2> "$TMP/err"
eq "factory bridge: factory without the native CLI is a missing dependency" "$?" 127
check "factory bridge: old factory remedy names the native deriver" "grep -q 'native contract deriver' '$TMP/err'"
( PATH=''; hash -r; plan_require_deriver ) > "$TMP/out" 2> "$TMP/err"
eq "factory bridge: missing Bun is a missing dependency" "$?" 127
check "factory bridge: missing Bun is diagnosed" "grep -q 'required tool: bun' '$TMP/err'"
summary
