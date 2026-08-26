#!/usr/bin/env bash
# The applier.
# Moved from test-upgrade.sh:798-1011.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/merge.sh"
. "$HERE/lib/upgrade-helpers.sh"

base="$PLUGIN_ROOT/base"
MAP_03="$(layout_map "$PLUGIN_ROOT" 0.3)"
MAP_PRE="$(layout_map "$PLUGIN_ROOT" pre-0.3)"

# ---- the applier --------------------------------------------------------
# A 0.2.1 fixture, because plugin/base/ is byte-identical between 0.3.0 and
# 0.3.1 and a 0.3.0 project therefore has nothing stale to replace.
#
# Skills are the assertion surface: .claude/skills/ is the SAME path in both
# layouts, so a pre-0.3 fixture's skills already sit where the target expects
# them. That lets apply_base be unit-tested without first running the hops.
#
# THE VACUITY TRAP this block is written against: a pre-0.3 project retains
# .inspire/{bin,hooks,skills,templates} as the staged source install.sh copied
# FROM, so "the destination exists" proves nothing. Every assertion below either
# names a path this test itself deleted or created, or compares content.

w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
mf="$PLUGIN_ROOT/manifests/0.2.1.json"
printf '\nMY EDIT\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
mine_hash="$(sha256_of "$p/.claude/skills/inspire-domain/SKILL.md")"
rm -f "$p/.claude/skills/inspire-adr/SKILL.md"
mkdir -p "$p/.claude/skills/inspire-code/references"
printf 'go rules\n' > "$p/.claude/skills/inspire-code/references/go-best-practices.md"

v="$(mktemp)"; classify "$mf" "$p" "$base" "$MAP_PRE" "$MAP_03" > "$v"
ks="$(mktemp)"; keepset_of "$v" "$p" > "$ks"
check "keepset holds the operator's edit" "grep -Fxq '$mine_hash' '$ks'"

# Record mode must not write.
before="$(tree_hash "$p")"
apply_base "$ks" "$mf" "$p" "$base" "$MAP_PRE" "$MAP_03" 1
after="$(tree_hash "$p")"
eq "applier in record mode wrote nothing" "$before" "$after"

apply_base "$ks" "$mf" "$p" "$base" "$MAP_PRE" "$MAP_03" 0
eq "applier exit status" "$?" "0"

eq "kept file is byte-identical to the operator's" \
   "$(sha256_of "$p/.claude/skills/inspire-domain/SKILL.md")" "$mine_hash"
check "deleted skill was restored" "[ -f '$p/.claude/skills/inspire-adr/SKILL.md' ]"
check "the restored skill is the target version's" \
   "same_file '$p/.claude/skills/inspire-adr/SKILL.md' '$base/skills/inspire-adr/SKILL.md'"
check "project-authored file survived the apply" \
   "[ -f '$p/.claude/skills/inspire-code/references/go-best-practices.md' ]"
check "a stale skill now matches the plugin base" \
   "same_file '$p/.claude/skills/inspire-task/SKILL.md' '$base/skills/inspire-task/SKILL.md'"
# A written file must not inherit mktemp's 0600 — hundreds of files would be
# silently tightened across an upgrade. Asserted on the file this test DELETED,
# so it is the applier's write being measured and not the fixture's own mode.
eq "a written file keeps a sane mode" \
   "$(mode_of "$p/.claude/skills/inspire-adr/SKILL.md" 2>/dev/null)" "644"

# Idempotency: re-classify after applying → no replace rows remain for skills.
v2="$(mktemp)"; classify "$mf" "$p" "$base" "$MAP_PRE" "$MAP_03" > "$v2"
eq "apply converges — no skill left to replace" \
   "$(awk -F'\t' '$1=="replace" && $2 ~ /^\.claude\/skills\//' "$v2" | wc -l | tr -d ' ')" "0"
eq "apply converges — no skill left to restore" \
   "$(awk -F'\t' '$1=="restore" && $2 ~ /^\.claude\/skills\//' "$v2" | wc -l | tr -d ' ')" "0"
rm -f "$v" "$v2" "$ks"; fixture_cleanup "$w"

# --- the applier on a same-layout source ---------------------------------
# 0.3 → 0.4 moves nothing, so the whole payload is already at its target path.
# Two things only this fixture can prove: bin/test/ is NOT installed (a 0.3
# project has no .inspire/bin/test/ for a staged copy to fake), and a restored
# hook comes back EXECUTABLE even though base/hooks/*.sh are 644 in git — the
# two registered hooks are invoked by path, so a 644 dispatch.sh is a broken
# runtime.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
mf="$PLUGIN_ROOT/manifests/0.3.1.json"
rm -f "$p/.claude/inspire/hooks/session-start.sh"
rm -f "$p/.inspire/bin/review.sh"
printf '\nMY EDIT\n' >> "$p/.inspire/bin/no-todos.sh"
mine_hash="$(sha256_of "$p/.inspire/bin/no-todos.sh")"

v="$(mktemp)"; classify "$mf" "$p" "$base" "$MAP_03" "$MAP_03" > "$v"
ks="$(mktemp)"; keepset_of "$v" "$p" > "$ks"
apply_base "$ks" "$mf" "$p" "$base" "$MAP_03" "$MAP_03" 0
eq "same-layout applier exit status" "$?" "0"

check "the bin/test harness is never installed" "[ ! -e '$p/.inspire/bin/test' ]"
check "a restored hook is executable" "[ -x '$p/.claude/inspire/hooks/session-start.sh' ]"
check "a restored validator is executable" "[ -x '$p/.inspire/bin/review.sh' ]"
check "a restored hook is the target version's" \
   "same_file '$p/.claude/inspire/hooks/session-start.sh' '$base/hooks/session-start.sh'"
eq "an edited validator is untouched" \
   "$(sha256_of "$p/.inspire/bin/no-todos.sh")" "$mine_hash"
# Applying twice must change nothing at all.
before="$(tree_hash "$p")"
apply_base "$ks" "$mf" "$p" "$base" "$MAP_03" "$MAP_03" 0
after="$(tree_hash "$p")"
eq "a second apply is a no-op" "$before" "$after"
rm -f "$v" "$ks"; fixture_cleanup "$w"

# --- the applier's second pass, on a synthetic world ---------------------
# Nothing INSPIRE has ever shipped was dropped between 0.2.1 and now except
# bin/test/ (which the pre-0.3 HOP removes, not the applier), so no real fixture
# exercises the deletion sweep at all. A synthetic base + manifest does, and it
# also proves the source→middle→target translation: the manifest paths below are
# in the PRE-0.3 space while the files sit where the 0.3 layout puts them, which
# is the state the applier actually runs in — after the hops.
sw="$(mktemp -d)"; sb="$sw/base"; sp="$sw/proj"
mkdir -p "$sb/bin/test" "$sp/.inspire/bin"
printf 'new lib\n'      > "$sb/bin/_lib.sh"          # shipped by the target
printf 'plain\n'        > "$sb/bin/README.md"        # shipped, not a script
printf 'harness\n'      > "$sb/bin/test/run-tests.sh"  # NEVER materialized
printf 'old lib\n'      > "$sp/.inspire/bin/_lib.sh"   # stale, untouched
printf 'dead\n'         > "$sp/.inspire/bin/dead.sh"   # dropped, untouched
printf 'MY WORK\n'      > "$sp/.inspire/bin/mine.sh"   # dropped, edited
printf 'yours\n'        > "$sp/.inspire/bin/authored.sh"  # never shipped
printf 'THEIRS\n'       > "$sp/.inspire/bin/held.sh"   # stale but in the keepset
printf 'ours\n'         > "$sb/bin/held.sh"
smf="$sw/m.json"
jq -n --arg lib "$(sha256_of "$sp/.inspire/bin/_lib.sh")" \
      --arg dead "$(sha256_of "$sp/.inspire/bin/dead.sh")" \
      --arg held "$(sha256_of "$sp/.inspire/bin/held.sh")" \
   '{version:"0.0.1",layout:"pre-0.3",files:{
      ".claude/bin/_lib.sh":$lib,
      ".claude/bin/dead.sh":$dead,
      ".claude/bin/held.sh":$held,
      ".claude/bin/mine.sh":"0000000000000000000000000000000000000000000000000000000000000000"}}' \
   > "$smf"
sks="$sw/keep"; sha256_of "$sp/.inspire/bin/held.sh" > "$sks"

sbefore="$(tree_hash "$sp")"
apply_base "$sks" "$smf" "$sp" "$sb" "bin:.claude/bin" "bin:.inspire/bin" 1
eq "synthetic record mode wrote nothing" "$(tree_hash "$sp")" "$sbefore"

apply_base "$sks" "$smf" "$sp" "$sb" "bin:.claude/bin" "bin:.inspire/bin" 0
eq "synthetic applier exit status" "$?" "0"

check "a stale file takes the target version" "same_file '$sp/.inspire/bin/_lib.sh' '$sb/bin/_lib.sh'"
check "a keepset hash beats staleness" "[ \"\$(cat '$sp/.inspire/bin/held.sh')\" = 'THEIRS' ]"
check "a dropped file we shipped is deleted" "[ ! -e '$sp/.inspire/bin/dead.sh' ]"
check "a dropped file they edited is kept" "[ -f '$sp/.inspire/bin/mine.sh' ]"
check "a file we never shipped is kept" "[ -f '$sp/.inspire/bin/authored.sh' ]"
check "bin/test is not installed by the applier" "[ ! -e '$sp/.inspire/bin/test' ]"
eq "a new .sh under bin/ is executable" "$(mode_of "$sp/.inspire/bin/_lib.sh")" "755"
eq "a new non-script is not executable" "$(mode_of "$sp/.inspire/bin/README.md")" "644"

# A directory where we ship a file is left strictly alone: `mv` would nest
# inside it rather than replace it, which is silent tree corruption.
rm -f "$sp/.inspire/bin/README.md"; mkdir -p "$sp/.inspire/bin/README.md"
apply_base "$sks" "$smf" "$sp" "$sb" "bin:.claude/bin" "bin:.inspire/bin" 0
check "a directory in the way is left alone, not nested into" \
   "[ -d '$sp/.inspire/bin/README.md' ] && [ -z \"\$(ls -A '$sp/.inspire/bin/README.md')\" ]"
rm -rf "$sw"

# --- pass 2's prune walks UP, not one level ---------------------------------
# A4 of the blind 0.1→0.4 verification: 0.1 shipped inspire-learn/SKILL.md AND
# inspire-learn/references/learnings-format.md, both dropped since. Removing
# SKILL.md cannot prune inspire-learn/ while references/ is still there, and when
# references/ was emptied a moment later nothing retried the grandparent — so the
# upgrade left an empty .claude/skills/inspire-learn/ that a clean install never
# creates. The prune must therefore ascend, and must stop at the layout's own
# destination root and at the first directory that is not empty.
pw="$(mktemp -d)"; pb="$pw/base"; pp="$pw/proj"
mkdir -p "$pb/skills" "$pp/.claude/skills/gone/deep" "$pp/.claude/skills/stay/deep"
printf 'kept upstream\n' > "$pb/skills/live.md"       # the target still ships this
printf 'kept upstream\n' > "$pp/.claude/skills/live.md"
printf 'dropped deep\n'  > "$pp/.claude/skills/gone/deep/x.md"
printf 'dropped mid\n'   > "$pp/.claude/skills/gone/y.md"
printf 'dropped deep2\n' > "$pp/.claude/skills/stay/deep/x2.md"
printf 'MINE\n'          > "$pp/.claude/skills/stay/deep/mine.md"   # never shipped
pmf="$pw/m.json"
jq -n --arg l "$(sha256_of "$pp/.claude/skills/live.md")" \
      --arg x "$(sha256_of "$pp/.claude/skills/gone/deep/x.md")" \
      --arg y "$(sha256_of "$pp/.claude/skills/gone/y.md")" \
      --arg x2 "$(sha256_of "$pp/.claude/skills/stay/deep/x2.md")" \
   '{version:"0.0.1",layout:"0.3",files:{
      ".claude/skills/live.md":$l,
      ".claude/skills/gone/deep/x.md":$x,
      ".claude/skills/gone/y.md":$y,
      ".claude/skills/stay/deep/x2.md":$x2}}' > "$pmf"
: > "$pw/keep"
apply_base "$pw/keep" "$pmf" "$pp" "$pb" "skills:.claude/skills" "skills:.claude/skills" 1
check "record mode pruned no directory" \
   "[ -d '$pp/.claude/skills/gone/deep' ] && [ -d '$pp/.claude/skills/gone' ]"
apply_base "$pw/keep" "$pmf" "$pp" "$pb" "skills:.claude/skills" "skills:.claude/skills" 0
eq "deep-prune applier exit status" "$?" "0"
check "premise: the dropped files really were removed" \
   "[ ! -e '$pp/.claude/skills/gone/deep/x.md' ] && [ ! -e '$pp/.claude/skills/gone/y.md' ]"
check "the prune ascends past the immediate parent" "[ ! -e '$pp/.claude/skills/gone' ]"
check "the prune stops at a directory holding the operator's file" \
   "[ -f '$pp/.claude/skills/stay/deep/mine.md' ]"
check "the prune never removes the layout's own destination root" \
   "[ -d '$pp/.claude/skills' ] && [ -f '$pp/.claude/skills/live.md' ]"

# The stop, asserted where it actually bites: a project whose whole destination
# root is dropped content, so the ascent reaches the root itself. The root is the
# layout's own container — pass 1 fills it on the very next run — and removing it
# would be the applier deleting a directory the target version owns.
rp="$pw/proj2"; mkdir -p "$rp/.claude/skills/only"
rb="$pw/base2"; mkdir -p "$rb/skills"   # ships nothing, so the root ends up empty
printf 'dropped\n' > "$rp/.claude/skills/only/z.md"
rmf="$pw/m2.json"
jq -n --arg z "$(sha256_of "$rp/.claude/skills/only/z.md")" \
   '{version:"0.0.1",layout:"0.3",files:{".claude/skills/only/z.md":$z}}' > "$rmf"
apply_base "$pw/keep" "$rmf" "$rp" "$rb" "skills:.claude/skills" "skills:.claude/skills" 0
check "premise: the only file under the root was removed" \
   "[ ! -e '$rp/.claude/skills/only/z.md' ]"
check "the emptied subdirectory went" "[ ! -e '$rp/.claude/skills/only' ]"
check "the destination root itself survives, even emptied" "[ -d '$rp/.claude/skills' ]"
rm -rf "$pw"

summary
