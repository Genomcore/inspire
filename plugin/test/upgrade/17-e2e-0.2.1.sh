#!/usr/bin/env bash
# End to end: 0.2.1 -> current.
# Moved from test-upgrade.sh:1232-1358.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/merge.sh"

base="$PLUGIN_ROOT/base"
MAP_03="$(layout_map "$PLUGIN_ROOT" 0.3)"
MZ="$PLUGIN_ROOT/scripts/materialize.sh"
target="$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")"

# ---- end to end: 0.2.1 → current ---------------------------------------
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
printf 'mine\n' > "$p/.claude/bin/test/my-fixture.sh"
mkdir -p "$p/.claude/skills/inspire-code/references"
printf 'go rules\n' > "$p/.claude/skills/inspire-code/references/go-best-practices.md"
printf '\nMY EDIT\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
mine_hash="$(shasum -a 256 "$p/.claude/skills/inspire-domain/SKILL.md" | awk '{print $1}')"

# seed_kb must run on UPGRADE, not just init — a 0.2 project has to finally
# receive the KB layers and files added since. Proving that needs care: 0.2.1's
# 21-file skeleton covers nearly all of today's 18-file base/kb (0.7.0 stopped
# shipping the three _index.md seeds and the two _template.md seeds, added
# 05_screens/components/.gitkeep to keep the emptied directory shipping, and
# added 00_bootstrap/glossary.md: 21 − 5 + 1 + 1 = 18), so the hop's
# `mv .inspire_kb inspire_kb` alone satisfies "every skeleton file
# is present" for everything but that .gitkeep and the glossary. Remove one
# whole layer and one file inside a layer that stays, so only a seed can put
# them back.
rm -rf "$p/.inspire_kb/98_lessons"
rm -f "$p/.inspire_kb/00_bootstrap/theme.md"
kb_before="$(find "$p/.inspire_kb" -type f | wc -l | tr -d ' ')"

bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "update exits 0" "$?" "0"

check "layout is now 0.3"       "[ -d '$p/inspire_kb' ] && [ -f '$p/.inspire/bin/review.sh' ]"
check "hooks relocated"         "[ -f '$p/.claude/inspire/hooks/dispatch.sh' ]"
eq    "lock reports the target" "$(jq -r .inspire_version "$p/.inspire.lock")" "$target"
check "lock no longer carries a files map" \
      "[ \"\$(jq -r 'has(\"files\")' '$p/.inspire.lock')\" = 'false' ]"
check "lock carries a real template_sha" \
      "[ \"\$(jq -r .template_sha '$p/.inspire.lock')\" != 'unknown' ]"
check "project-authored reference survived" \
      "[ -f '$p/.claude/skills/inspire-code/references/go-best-practices.md' ]"
check "operator fixture survived" "[ -f '$p/.claude/bin/test/my-fixture.sh' ]"
eq    "edited skill kept by default" \
      "$(shasum -a 256 "$p/.claude/skills/inspire-domain/SKILL.md" | awk '{print $1}')" "$mine_hash"
check "KB gained no losses" \
      "[ \"\$(find '$p/inspire_kb' -type f | wc -l | tr -d ' ')\" -ge '$kb_before' ]"

check "seed_kb ran on upgrade: a wholly missing layer came back" \
      "[ -f '$p/inspire_kb/98_lessons/README.md' ]"
check "seed_kb ran on upgrade: a missing file inside a kept layer came back" \
      "[ -f '$p/inspire_kb/00_bootstrap/theme.md' ]"

# Every file in the plugin's KB skeleton must now exist in the project. Asserting
# on inspire_kb/README.md alone would pass trivially: the hop MOVES the 0.2
# .inspire_kb/README.md there, so it proves nothing about seed_kb having run.
missing_kb=0
while IFS= read -r f; do
  [ -f "$p/inspire_kb/${f#"$PLUGIN_ROOT/base/kb/"}" ] || missing_kb=$((missing_kb+1))
done < <(find "$PLUGIN_ROOT/base/kb" -type f)
eq "KB received every file of the newer skeleton" "$missing_kb" "0"

# settings.json: exactly the two marked hooks, and none of the three old ones.
eq "two INSPIRE-MANAGED hooks registered" \
   "$(jq '[.. | objects | select(has("command")) | select(.command|contains("INSPIRE-MANAGED"))] | length' \
      "$p/.claude/settings.json")" "2"
eq "no .claude/hooks registrations remain" \
   "$(jq '[.. | objects | select(has("command")) | select(.command|contains(".claude/hooks/"))] | length' \
      "$p/.claude/settings.json")" "0"

# Re-running converges — WHEN THE TREE IT JUST WROTE CAN STILL BE DETECTED.
#
# THE PREMISE, and it is not a constant: a second `update` re-detects the project
# from scratch, and detect_version nominates nothing below MANIFEST_FLOOR_PCT. A
# post-update tree is a copy of today's plugin/base/, so it only scores above that
# floor against the NEWEST SHIPPED manifest while base/ is still byte-identical to
# what that manifest recorded. Mid-release it is not: the version being prepared
# has no manifest yet — it is generated from the version-bump commit, at release
# step T11-3 — and every base/ file this release legitimately edits drags the score
# against the last shipped one further down. So mid-release the second run refuses,
# and that refusal IS the design: detect_version would rather stop than upgrade
# from a baseline it had to guess.
#
# Asserting only "exits 0" would therefore be a test unfulfillable at every commit;
# asserting only the refusal would go stale the hour the manifest lands. So the
# outcome is DERIVED from the machinery instead — re-detect with the same function
# materialize.sh calls, and pin whichever of the two behaviours it predicts. Both
# are pinned below; T11-3 flips the branch with no edit here.
#
# Two vacuity guards, because "it refused" is worthless if it refused for some
# other reason: the refusal must be DETECTION's (its own wording), and it must name
# the floor by the value the constant actually holds — not merely have failed.
detect_version "$PLUGIN_ROOT" "$p" >/dev/null 2>&1; rerun_detectable=$?
rerun_lock="$(shasum -a 256 "$p/.inspire.lock" | awk '{print $1}')"
rerun_err="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1 >/dev/null)"
rerun_rc=$?
if [ "$rerun_detectable" -eq 0 ]; then
  eq "released state: update is re-runnable" "$rerun_rc" "0"
else
  eq "mid-release: the 0.2.1 tree's second run refuses (rc)" "$rerun_rc" "1"
  eq "mid-release: the refusal is detection's own" \
     "$(printf '%s\n' "$rerun_err" | grep -c "cannot identify this project's INSPIRE version")" "1"
  eq "mid-release: the refusal names the score floor it fell under" \
     "$(printf '%s\n' "$rerun_err" | grep -c "floor ${MANIFEST_FLOOR_PCT}%")" "1"
  eq "mid-release: a refused run restamps no lock" \
     "$(shasum -a 256 "$p/.inspire.lock" | awk '{print $1}')" "$rerun_lock"
fi
# Unconditional: whether the second run converged or refused, the operator's edit
# is still theirs. A refusal that damaged the tree would be no better than a guess.
eq "edit still kept after a second run" \
   "$(shasum -a 256 "$p/.claude/skills/inspire-domain/SKILL.md" | awk '{print $1}')" "$mine_hash"

# The 0.2 staging tree survives at .inspire/bin/test/ — the hop reports it as
# residue and deliberately leaves it, since an operator's un-reinstalled edit
# could be in there. But .inspire/bin IS the 0.3 destination for `bin`, so
# classify's pass 3 walked those 114 files, found them absent from `seen`, and
# labelled every one "yours — INSPIRE never shipped this" on this and every later
# run. We shipped every byte of them; it is the same false ownership claim the
# 0.3.0 hop had removed, arriving from the other side, and it contradicted the
# hop's own report. The premise is asserted first — with the residue gone the
# count below would be 0 for the wrong reason.
residue_n="$(find "$p/.inspire/bin/test" -type f 2>/dev/null | wc -l | tr -d ' ')"
eq "premise: the 0.2 staged fixture residue is still on disk" "$residue_n" "114"
rv="$(mktemp)"
classify "$PLUGIN_ROOT/manifests/0.3.1.json" "$p" "$base" "$MAP_03" "$MAP_03" > "$rv"
eq "staged source residue is never claimed as the operator's" \
   "$(awk -F'\t' '$1=="keep" && $2 ~ /^\.inspire\/bin\/test\// && $3 ~ /yours/' "$rv" | wc -l | tr -d ' ')" "0"
# ...and the skip is narrow: a genuinely project-authored file inside a directory
# INSPIRE owns must still be reported as theirs. Without this the fix could have
# silenced pass 3 altogether and still passed the assertion above.
check "a genuinely project-authored file is still reported as theirs" \
   "awk -F'\t' '\$1==\"keep\" && \$3 ~ /yours/' '$rv' | grep -q 'go-best-practices.md'"
rm -f "$rv"
fixture_cleanup "$w"

summary
