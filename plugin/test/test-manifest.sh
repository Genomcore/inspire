#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
GEN="$HERE/../scripts/gen-manifest.sh"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
# A SKIP is counted and printed in the summary. A skip that does not surface is
# indistinguishable from coverage, which is how a permanently-skipped check turns
# into false confidence.
skipped=0
skip(){ echo "SKIP $1"; skipped=$((skipped+1)); }
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

# Every committed manifest must be reproducible from its tag. A manifest that
# cannot be regenerated means the release is broken — this is the only thing
# keeping the content baseline honest.
mf_count=0
mf_pending=0
for f in "$HERE/../manifests"/*.json; do
  [ -f "$f" ] || continue
  mf_count=$((mf_count+1))
  v="$(basename "$f" .json)"
  # An in-flight release has a manifest but no tag yet: the bump and the manifest
  # land in one PR and the tag is cut when it merges. That is PENDING, not passing
  # and not failing — a red suite everyone expects to be red trains people to
  # ignore red, and a silent pass would hide the regeneration step entirely.
  if ! git -C "$REPO" rev-parse -q --verify "refs/tags/v$v" >/dev/null 2>&1; then
    skip "manifest $v — no v$v tag yet; REGENERATE FROM THE TAG once it is cut"
    mf_pending=$((mf_pending+1))
    continue
  fi
  live="$(bash "$GEN" --tag "v$v" --repo "$REPO")"
  if [ "$live" = "$(cat "$f")" ]; then
    ok "manifest $v reproduces from tag"
  else
    bad "manifest $v does NOT reproduce from tag"
  fi
done
[ "$mf_pending" -eq 0 ] || echo "  NOTE: $mf_pending manifest(s) await their tag — regenerate before opening the PR."
if [ "$mf_count" -eq 0 ]; then
  bad "no manifests found under plugin/manifests — the sweep cannot pass vacuously"
else
  ok "sweep covered $mf_count manifest(s)"
fi

echo ""; echo "Passed: $pass · Failed: $fail · Skipped: $skipped"
[ "$fail" -eq 0 ]
