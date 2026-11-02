#!/usr/bin/env bash
# plugin/base/bin/test/test-translated-kb.sh — a KB written in another
# output_language reads exactly as its English twin
#
# Usage: bash plugin/base/bin/test/test-translated-kb.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
REVIEW="$HERE/../review.sh"
TWINS="$HERE/translated-kb"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1"; diff <(printf '%s\n' "$3") <(printf '%s\n' "$2") | sed 's/^/    /'; fi; }
has(){ if printf '%s\n' "$3" | grep -qF -- "$2"; then ok "$1"; else bad "$1 (no match for '$2')"; fi; }

findings() {
  local root="$TWINS/$1" scope
  for scope in sdd kb; do
    SDD_SPEC_ROOT="$root/sdd" SDD_KB_ROOT="$root/kb" "$REVIEW" "$root/$scope" 2>&1 >/dev/null
  done | sed "s#$root/##g" | sort
}

EN="$(findings en)"
ES="$(findings es)"

has "the English twin reports an undeclared field"   '"rule":"action-fields-in-entity"' "$EN"
has "the English twin reports an orphan write"       '"rule":"entity-coherence"' "$EN"
has "the English twin reports a duplicated error"    'OS-A9' "$EN"
has "the English twin reports a stray constraint"    'OS-E9' "$EN"
has "the English twin reports an unknown head arg"   'OS-X2' "$EN"
has "the English twin reports an unresolved state"   "state 'gone'" "$EN"
has "the English twin reports an undeclared param"   "param 'tab'" "$EN"
has "the English twin reads the render columns"      "Narrow 'wide'" "$EN"

has "prose-style says it is en-only for the Spanish twin" 'output_language: es' "$ES"
eq  "every other finding is the same in both languages" \
    "$(printf '%s\n' "$ES" | grep -v '"rule":"prose-style"')" \
    "$(printf '%s\n' "$EN" | grep -v '"rule":"prose-style"')"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
