#!/usr/bin/env bash
# Tests plugin/test/lib/fixtures.sh — the period-correct fixture builder.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
. "$HERE/lib/fixtures.sh"

pass=0; fail=0
ok()   { echo "PASS $1"; pass=$((pass+1)); }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

w2="$(mktemp -d)"
p2="$(fixture_from_tag v0.2.1 "$w2" "$REPO")"

check "0.2.1 fixture: KB at .inspire_kb"      "[ -d '$p2/.inspire_kb' ]"
check "0.2.1 fixture: no inspire_kb"          "[ ! -d '$p2/inspire_kb' ]"
check "0.2.1 fixture: validators at .claude/bin" "[ -f '$p2/.claude/bin/review.sh' ]"
check "0.2.1 fixture: hooks at .claude/hooks"    "[ -f '$p2/.claude/hooks/session-start.sh' ]"
check "0.2.1 fixture: fixtures were copied"      "[ -d '$p2/.claude/bin/test' ]"
check "0.2.1 fixture: lock says 0.2.1" \
  "[ \"\$(jq -r .inspire_version '$p2/.inspire.lock')\" = '0.2.1' ]"
check "0.2.1 fixture: lock has no files map" \
  "[ \"\$(jq -r 'has(\"files\")' '$p2/.inspire.lock')\" = 'false' ]"
fixture_cleanup "$w2"

w3="$(mktemp -d)"
p3="$(fixture_from_tag v0.3.1 "$w3" "$REPO")"
check "0.3.1 fixture: KB at inspire_kb"       "[ -d '$p3/inspire_kb' ]"
check "0.3.1 fixture: validators at .inspire/bin" "[ -f '$p3/.inspire/bin/review.sh' ]"
check "0.3.1 fixture: no bin/test"            "[ ! -d '$p3/.inspire/bin/test' ]"
check "0.3.1 fixture: lock has files map" \
  "[ \"\$(jq -r 'has(\"files\")' '$p3/.inspire.lock')\" = 'true' ]"
fixture_cleanup "$w3"

echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
