#!/usr/bin/env bash
# Per-tag manifest shape, and one definition of what base/ ships.
# Moved from test-manifest.sh:18-49, 102-107.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
GEN="$HERE/../scripts/gen-manifest.sh"
. "$HERE/lib/assert.sh"

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

# ONE definition of "what base/ actually ships", not two. The generator held a
# re-expressed copy of the rule while lib/merge.sh's _base_excluded was the
# definition the classifier and the applier used. Neither copy had drifted, but a
# second copy is the only place this rule CAN drift — and a manifest that
# disagreed with the applier about what ships turns every affected path into a
# phantom deletion or a phantom creation.
eq "the base-exclusion rule is defined exactly once under scripts/" \
  "$(grep -rl '^_base_excluded()' "$HERE/../scripts" | wc -l | tr -d ' ')" "1"
check "gen-manifest.sh asks that definition instead of re-expressing it" \
  "grep -q 'lib/merge.sh' '$GEN' && grep -q '_base_excluded \"\$name\" \"\$rel\"' '$GEN'"
# Reproducibility: same tag twice → byte-identical.
a="$(bash "$GEN" --tag v0.2.1 --repo "$REPO")"
b="$(bash "$GEN" --tag v0.2.1 --repo "$REPO")"
eq "deterministic output" "$a" "$b"

rm -f "$m21" "$m31"
summary
