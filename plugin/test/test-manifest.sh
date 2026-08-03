#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
GEN="$HERE/../scripts/gen-manifest.sh"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

m21="$(mktemp)"; bash "$GEN" --tag v0.2.1 --repo "$REPO" > "$m21"
eq "0.2.1 version"  "$(jq -r .version  "$m21")" "0.2.1"
eq "0.2.1 layout"   "$(jq -r .layout   "$m21")" "pre-0.3"
eq "0.2.1 commit"   "$(jq -r '.commit|length' "$m21")" "40"
eq "0.2.1 file count" "$(jq -r '.files|length' "$m21")" "192"
check "0.2.1 maps skills into .claude/skills" \
  "[ \"\$(jq -r '.files[\".claude/skills/inspire-domain/SKILL.md\"]|length' '$m21')\" = 64 ]"
check "0.2.1 includes the copied fixtures" \
  "[ \"\$(jq -r '[.files|keys[]|select(startswith(\".claude/bin/test/\"))]|length' '$m21')\" = 114 ]"
check "0.2.1 has no plugin-side paths" \
  "[ \"\$(jq -r '[.files|keys[]|select(startswith(\"plugin/\"))]|length' '$m21')\" = 0 ]"

m31="$(mktemp)"; bash "$GEN" --tag v0.3.1 --repo "$REPO" > "$m31"
eq "0.3.1 layout"     "$(jq -r .layout "$m31")" "0.3"
eq "0.3.1 file count" "$(jq -r '.files|length' "$m31")" "79"
check "0.3.1 maps bin into .inspire/bin" \
  "[ \"\$(jq -r '.files|has(\".inspire/bin/review.sh\")' '$m31')\" = true ]"
check "0.3.1 maps hooks into .claude/inspire/hooks" \
  "[ \"\$(jq -r '.files|has(\".claude/inspire/hooks/dispatch.sh\")' '$m31')\" = true ]"
check "0.3.1 excludes bin/test" \
  "[ \"\$(jq -r '[.files|keys[]|select(contains(\"/test/\"))]|length' '$m31')\" = 0 ]"

# Reproducibility: same tag twice → byte-identical.
a="$(bash "$GEN" --tag v0.2.1 --repo "$REPO")"
b="$(bash "$GEN" --tag v0.2.1 --repo "$REPO")"
eq "deterministic output" "$a" "$b"

rm -f "$m21" "$m31"
echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
