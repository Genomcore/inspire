#!/usr/bin/env bash
# Tests the upgrade path: detection, layout signatures, hop ops, the chain,
# the three-way merge, and end-to-end chains.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

pass=0; fail=0; skip=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
# A block that cannot run must not masquerade as coverage: count the assertions
# it would have made and surface them in the summary, so an environment where it
# never runs (CI as root, where chmod 555 does not bite) shows the gap instead of
# reading all-green. skipped <n> <why>.
skipped(){ echo "SKIP $2 ($1 assertions)"; skip=$((skip+$1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# ---- detection ----------------------------------------------------------
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"

eq "detect 0.2.1 from a clean fixture" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

rm -f "$p/.inspire.lock"
eq "detect 0.2.1 with no lock at all" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

jq -n '{inspire_version:"0.3.1",released:"x",template_sha:"x",installed_at:"x"}' \
  > "$p/.inspire.lock"
eq "detect ignores a lying lock" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

# Local edits must not change the nomination.
printf '\nLOCAL EDIT\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
rm -f "$p/.claude/bin/no-todos.sh"
eq "detect survives operator edits and deletions" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"
fixture_cleanup "$w"

# A tree with nothing of ours in it cannot be nominated.
empty="$(mktemp -d)"; ( cd "$empty" && git init -q )
detect_version "$PLUGIN_ROOT" "$empty" >/dev/null 2>&1; rc=$?
eq "detect refuses an unrecognisable tree" "$rc" "1"
rm -rf "$empty"

# ---- N-way tie bookkeeping (Task 5 review findings) ---------------------
# A single min/max pair can only ever remember one runner-up, so a 3+-way tie
# would silently drop all but one contender. Build synthetic manifests in a
# scratch plugin_root — plugin/manifests/ is never touched.
tie_w="$(mktemp -d)"
tie_plugin="$tie_w/plugin"; mkdir -p "$tie_plugin/manifests"
tie_proj="$tie_w/proj"; mkdir -p "$tie_proj"
printf 'shared\n' > "$tie_proj/shared.txt"
tie_h="$(sha256_of "$tie_proj/shared.txt")"

# Three candidates, all scoring 100%, spanning two DIFFERENT layouts (A, A, B).
jq -n --arg h "$tie_h" '{version:"1.0.0",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.0.0.json"
jq -n --arg h "$tie_h" '{version:"1.0.1",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.0.1.json"
jq -n --arg h "$tie_h" '{version:"2.0.0",released:"x",commit:"x",layout:"B",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/2.0.0.json"

tie_err="$(detect_version "$tie_plugin" "$tie_proj" 2>&1 >/dev/null)"; tie_rc=$?
eq "N-way cross-layout tie is refused (rc)" "$tie_rc" "1"
check "N-way cross-layout tie mentions all three candidates" \
  "printf '%s' \"\$tie_err\" | grep -q '1.0.0' && printf '%s' \"\$tie_err\" | grep -q '1.0.1' && printf '%s' \"\$tie_err\" | grep -q '2.0.0'"

# Same three-candidate shape, but all SAME layout: must still resolve, to the
# highest version — a same-layout tie is the normal, safe case.
rm -f "$tie_plugin/manifests/2.0.0.json"
jq -n --arg h "$tie_h" '{version:"1.5.0",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.5.0.json"
eq "N-way same-layout tie resolves to the highest version" \
  "$(detect_version "$tie_plugin" "$tie_proj" 2>/dev/null | cut -f1)" "1.5.0"
fixture_cleanup "$tie_w"

# ---- empty-array expansion under bash 3.2 + set -u -----------------------
# manifest_versions yielding nothing (no manifests present, no lock hint)
# must not crash the calling script with an unbound-variable error — it must
# return the documented rc=1.
noman_w="$(mktemp -d)"
noman_plugin="$noman_w/plugin"; mkdir -p "$noman_plugin/manifests"
noman_proj="$noman_w/proj"; mkdir -p "$noman_proj"
noman_err="$(detect_version "$noman_plugin" "$noman_proj" 2>&1 >/dev/null)"; noman_rc=$?
eq "empty manifests dir returns rc=1, not a crash" "$noman_rc" "1"
check "empty manifests dir does not raise an unbound-variable error" \
  "! printf '%s' \"\$noman_err\" | grep -qi 'unbound variable'"
fixture_cleanup "$noman_w"

# ---- layout signatures --------------------------------------------------
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "0.2.1 tree satisfies the pre-0.3 signature" "$?" "0"

verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.2.1 tree fails the 0.3 signature" "$?" "1"

# Half-migrated by hand: both KB roots present. We cannot tell which is live.
mkdir -p "$p/inspire_kb"
out="$(verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 2>&1)"; rc=$?
eq "half-migrated tree is refused" "$rc" "1"
check "refusal explains the ambiguity" \
  "printf '%s' \"\$out\" | grep -qi 'inspire_kb'"
fixture_cleanup "$w"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.3.1 tree satisfies the 0.3 signature" "$?" "0"
fixture_cleanup "$w"

verify_layout "$PLUGIN_ROOT" "$p" no-such-layout >/dev/null 2>&1
eq "unknown layout id is refused" "$?" "1"

eq "layout_map for pre-0.3 puts bin under .claude" \
   "$(layout_map "$PLUGIN_ROOT" pre-0.3)" \
   "bin:.claude/bin hooks:.claude/hooks skills:.claude/skills"
eq "layout_map for 0.3 puts bin under .inspire" \
   "$(layout_map "$PLUGIN_ROOT" 0.3)" \
   "bin:.inspire/bin hooks:.claude/inspire/hooks skills:.claude/skills"
layout_map "$PLUGIN_ROOT" no-such-layout >/dev/null 2>&1
eq "layout_map refuses an unknown layout" "$?" "1"

# ---- fix round 1: .claude/bin & .claude/hooks are not INSPIRE-exclusive ---
# `.claude/bin`/`.claude/hooks` are ordinary Claude Code locations an operator
# may legitimately keep their own content in — including, after an INSPIRE-
# performed 0.3.0 hop, leftover foreign entries the hop deliberately never
# touches (it only ever removes entries IT owns). Neither may appear in a
# signature's must_not_exist list; the KB root plus the INSPIRE-exclusive
# .claude/inspire/hooks namespace are the only safe discriminators. This
# section is permanent regression coverage for that finding.

# Direction: a 0.3 fixture must also FAIL the pre-0.3 signature.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "0.3.1 tree fails the pre-0.3 signature" "$?" "1"

# The regression itself: operator-owned content under .claude/bin and
# .claude/hooks on an otherwise-clean 0.3 tree must not flip the outcome.
mkdir -p "$p/.claude/hooks" "$p/.claude/bin"
printf '#!/usr/bin/env bash\necho mine\n' > "$p/.claude/hooks/my-own-hook.sh"
printf '#!/usr/bin/env bash\necho mine\n' > "$p/.claude/bin/my-tool.sh"
verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.3 tree with operator's own .claude/hooks and .claude/bin still passes 0.3" "$?" "0"

# Half-migrated the other direction: both KB roots present, checked against
# the 0.3 signature this time — must also be refused as ambiguous, naming
# the offending path.
mkdir -p "$p/.inspire_kb"
out="$(verify_layout "$PLUGIN_ROOT" "$p" 0.3 2>&1)"; rc=$?
eq "half-migrated tree is refused against the 0.3 signature too" "$rc" "1"
check "0.3-side refusal explains the ambiguity" \
  "printf '%s' \"\$out\" | grep -qi 'inspire_kb'"
fixture_cleanup "$w"

# Structure-not-content, as a permanent assertion rather than a one-off
# manual demonstration: a deleted validator, an edited skill file, and an
# entire removed skill directory must never affect the outcome.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
rm -f "$p/.claude/bin/no-todos.sh"
printf '\nOPERATOR CUSTOMIZATION\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
rm -rf "$p/.claude/skills/inspire-spike"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "deleted validator, edited skill, removed skill dir still pass pre-0.3" "$?" "0"
fixture_cleanup "$w"

# ---- hop ops ------------------------------------------------------------
. "$PLUGIN_ROOT/scripts/lib/hop-ops.sh"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
mf="$PLUGIN_ROOT/manifests/0.2.1.json"

# --- act mode ---
hop_ops_init "$p" "$mf" 0
mkdir -p "$p/.inspire/bin"
hop_mv .claude/bin/review.sh .inspire/bin/review.sh
check "hop_mv moved the file"        "[ -f '$p/.inspire/bin/review.sh' ]"
check "hop_mv left no source behind" "[ ! -e '$p/.claude/bin/review.sh' ]"

# The check above is vacuous on its own: a pre-0.3 project legitimately retains
# .inspire/bin/review.sh — the staged source install.sh copied FROM — so the
# destination already existed (verified: it passes even with hop_mv undefined).
# Only "left no source behind" fails without hop_mv. Prove a real transfer, and
# the destination-dir creation, against a path nothing could have pre-created.
printf 'CANARY\n' > "$p/.claude/bin/hop-canary.txt"
hop_mv .claude/bin/hop-canary.txt .inspire/fresh/hop-canary.txt
check "hop_mv creates the missing destination directory" "[ -d '$p/.inspire/fresh' ]"
eq "hop_mv transferred the content intact" \
  "$(cat "$p/.inspire/fresh/hop-canary.txt" 2>/dev/null)" "CANARY"
check "hop_mv journalled move with both paths" \
  "grep -q \$'^move\t.claude/bin/hop-canary.txt\t.inspire/fresh/hop-canary.txt$' '$HOP_JOURNAL'"

# Moving a path onto itself: `mv same same` succeeds silently but leaves the
# source present, so the disk-state success test read it as a failure and
# journalled a false "could not be moved (unknown error)". A false failure is
# the same sin as a false success.
printf 'SELF\n' > "$p/.claude/bin/self-move.txt"
selfmv_j="$(wc -l < "$HOP_JOURNAL" | tr -d ' ')"
hop_mv .claude/bin/self-move.txt .claude/bin/self-move.txt 2>/dev/null
eq "hop_mv onto itself returns 0" "$?" "0"
eq "hop_mv onto itself journals nothing" \
  "$(wc -l < "$HOP_JOURNAL" | tr -d ' ')" "$selfmv_j"
eq "hop_mv onto itself leaves the file intact" \
  "$(cat "$p/.claude/bin/self-move.txt" 2>/dev/null)" "SELF"

hop_mv .claude/bin/definitely-absent.sh .inspire/bin/definitely-absent.sh
eq "hop_mv on a missing source is a silent no-op" "$?" "0"
check "hop_mv created nothing from nothing" "[ ! -e '$p/.inspire/bin/definitely-absent.sh' ]"

# A move that EMPTIES its source directory must take the container with it. The
# 0.3.0 hop drains .claude/bin/ and .claude/hooks/ completely, and without this
# both survived as empty directories a clean install never creates (A2/A3 of the
# blind 0.1→0.4 verification).
#
# Probe paths the pre-0.3 installer could never have staged, so neither the
# assertion nor its premise can be satisfied by fixture residue.
mkdir -p "$p/.claude/prune-solo"
printf 'ONLY\n' > "$p/.claude/prune-solo/only.txt"
prune_j_before="$(wc -l < "$HOP_JOURNAL" | tr -d ' ')"
hop_mv .claude/prune-solo/only.txt .inspire/pruned/only.txt
eq "the emptying move succeeded" "$?" "0"
check "hop_mv removed the directory its move emptied" "[ ! -e '$p/.claude/prune-solo' ]"
check "the moved file is at its destination" "[ -f '$p/.inspire/pruned/only.txt' ]"
# The prune is deliberately silent — an empty directory disappearing needs no
# forewarning, and record mode cannot forecast it. So exactly ONE line was added:
# the move. Nothing may claim the directory removal.
eq "a pruning move journals only its move line" \
  "$(wc -l < "$HOP_JOURNAL" | tr -d ' ')" "$((prune_j_before + 1))"

# ...and stops dead at anything of the operator's: rmdir refuses a non-empty
# directory, which is the whole safety argument for doing this at all.
mkdir -p "$p/.claude/prune-shared"
printf 'OURS\n'  > "$p/.claude/prune-shared/ours.txt"
printf 'THEIRS\n' > "$p/.claude/prune-shared/theirs.txt"
hop_mv .claude/prune-shared/ours.txt .inspire/pruned/ours.txt
check "a directory still holding a file is left alone" "[ -d '$p/.claude/prune-shared' ]"
eq "the file that blocked the prune is untouched" \
  "$(cat "$p/.claude/prune-shared/theirs.txt" 2>/dev/null)" "THEIRS"

# hop_rm_owned deletes only what the manifest says we shipped.
printf 'mine\n' > "$p/.claude/bin/test/my-fixture.sh"
owned_before="$(jq -r '[.files|keys[]|select(startswith(".claude/bin/test/"))]|length' "$mf")"
eq "manifest lists the shipped fixtures" "$owned_before" "114"
# A file we shipped that the operator EDITED must also survive. Pick the target
# deterministically from the manifest — not `find | head -1`, whose result
# depends on filesystem order.
edited_rel="$(manifest_paths "$mf" | cut -f1 | grep '^\.claude/bin/test/' \
              | LC_ALL=C sort | head -1)"
check "picked a shipped fixture deterministically" "[ -n '$edited_rel' ]"
printf '\nMY EDIT\n' >> "$p/$edited_rel"
edited_hash="$(shasum -a 256 "$p/$edited_rel" | awk '{print $1}')"

hop_rm_owned .claude/bin/test
check "hop_rm_owned kept the operator's fixture" "[ -f '$p/.claude/bin/test/my-fixture.sh' ]"
check "hop_rm_owned removed a file we shipped" \
  "[ ! -e '$p/.claude/bin/test/run-tests.sh' ]"
check "hop_rm_owned reported the survivor" \
  "grep -q 'my-fixture.sh' '$HOP_JOURNAL'"
check "hop_rm_owned never deletes a file we shipped but they edited" \
  "[ -f '$p/$edited_rel' ]"
eq "the edited shipped file is byte-identical" \
  "$(shasum -a 256 "$p/$edited_rel" 2>/dev/null | awk '{print $1}')" "$edited_hash"

# Count FILE deletions only. The directory-level line is `delete\t<prefix>/`,
# which a bare `^delete\t<prefix>/` grep also matches — requiring one more
# character after the final slash separates the two for good.
hop_deletes() { awk -F'\t' '$1=="delete" && $2 ~ /^\.claude\/bin\/test\/./' "$1" | wc -l | tr -d ' '; }
act_deletes="$(hop_deletes "$HOP_JOURNAL")"
eq "act mode deleted 114 shipped files minus the 1 they edited" "$act_deletes" "113"

# A journal that contradicts itself is worse than a silent one: the operator
# decides what to trust from these lines. An edited shipped file gets exactly
# ONE verdict — previously it also drew "yours — not shipped by INSPIRE",
# which was false about a file INSPIRE shipped.
eq "the edited file draws exactly one journal line" \
  "$(grep -c -F "	$edited_rel	" "$HOP_JOURNAL")" "1"
eq "no shipped file is ever labelled 'yours'" \
  "$(awk -F'\t' '$3 ~ /not shipped by INSPIRE/ {print $2}' "$HOP_JOURNAL" | wc -l | tr -d ' ')" "1"
check "the one 'yours' line is the operator's own file" \
  "[ \"\$(awk -F'\t' '\$3 ~ /not shipped by INSPIRE/ {print \$2}' '$HOP_JOURNAL')\" = '.claude/bin/test/my-fixture.sh' ]"

# `mv a b` with b an existing DIRECTORY does not replace b — it puts a inside
# it, yielding b/a, and reports success. Reachable for real: a pre-0.3 project
# retains .inspire/bin as the staged source, so a hop moving .claude/bin onto
# it would silently produce .inspire/bin/bin. Refuse, and journal nothing.
mkdir -p "$p/.claude/nest-src" "$p/.inspire/nest-dst/payload"
printf 'PAYLOAD\n' > "$p/.claude/nest-src/payload"
nest_j_before="$(wc -l < "$HOP_JOURNAL" | tr -d ' ')"
nest_err="$(hop_mv .claude/nest-src/payload .inspire/nest-dst/payload 2>&1 >/dev/null)"; nest_rc=$?
eq "hop_mv refuses a destination that is a directory" "$nest_rc" "1"
check "hop_mv did not nest the source inside the destination" \
  "[ ! -e '$p/.inspire/nest-dst/payload/payload' ]"
check "hop_mv left the refused source where it was" \
  "[ -f '$p/.claude/nest-src/payload' ]"
eq "a refused hop_mv journals nothing" \
  "$(wc -l < "$HOP_JOURNAL" | tr -d ' ')" "$nest_j_before"
check "the hop_mv refusal names both paths on stderr" \
  "printf '%s' \"\$nest_err\" | grep -q 'nest-src/payload' && printf '%s' \"\$nest_err\" | grep -q 'nest-dst/payload'"

# hop_rm removes ONE FILE. `rm -f` cannot remove a directory, so it used to
# leak a raw "is a directory" error after already journalling the delete.
mkdir -p "$p/.claude/rmdir-probe/sub"
printf 'keep\n' > "$p/.claude/rmdir-probe/sub/keepme.txt"
rmd_j_before="$(wc -l < "$HOP_JOURNAL" | tr -d ' ')"
rmd_err="$(hop_rm .claude/rmdir-probe/sub 2>&1 >/dev/null)"; rmd_rc=$?
eq "hop_rm refuses a directory" "$rmd_rc" "1"
check "hop_rm left the refused directory and its contents" \
  "[ -f '$p/.claude/rmdir-probe/sub/keepme.txt' ]"
eq "a refused hop_rm journals nothing" \
  "$(wc -l < "$HOP_JOURNAL" | tr -d ' ')" "$rmd_j_before"
check "hop_rm explains itself instead of leaking a raw rm error" \
  "printf '%s' \"\$rmd_err\" | grep -q 'it is a directory' && ! printf '%s' \"\$rmd_err\" | grep -q '^rm:'"
check "hop_rm points at hop_rm_owned for directories" \
  "printf '%s' \"\$rmd_err\" | grep -q 'hop_rm_owned'"

hop_report 'a note for the operator'
check "hop_report journals the note" "grep -q 'a note for the operator' '$HOP_JOURNAL'"
hop_unregister_hook '.claude/hooks/'
check "hop_unregister_hook journals the substring" \
  "grep -q \$'unregister\t.claude/hooks/' '$HOP_JOURNAL'"
fixture_cleanup "$w"

# --- record mode writes nothing ---
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
hop_ops_init "$p" "$mf" 1
# A source directory holding exactly one file: in ACT mode this move prunes it.
mkdir -p "$p/.claude/rec-prune"
printf 'REC\n' > "$p/.claude/rec-prune/only.txt"
before="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
# DIRECTORIES too, not only files: act mode now prunes a directory its own move
# empties, and a file-only fingerprint cannot see an empty directory vanish. If
# record mode ever grew that prune, this is the assertion that catches it.
dirs_before="$(find "$p" -type d | LC_ALL=C sort | shasum -a 256)"
hop_mv .claude/rec-prune/only.txt .inspire/rec-pruned/only.txt
hop_mv .claude/bin/review.sh .inspire/bin/review.sh
hop_rm_owned .claude/bin/test
hop_rm .inspire/install.sh
after="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "record mode wrote nothing" "$before" "$after"
eq "record mode removed no directory either" \
  "$(find "$p" -type d | LC_ALL=C sort | shasum -a 256)" "$dirs_before"
check "record mode left the would-be-pruned directory in place" \
  "[ -d '$p/.claude/rec-prune' ] && [ -f '$p/.claude/rec-prune/only.txt' ]"
check "record mode journalled the move" \
  "grep -q \$'move\t.claude/bin/review.sh' '$HOP_JOURNAL'"
eq "record mode journalled 114 deletions" "$(hop_deletes "$HOP_JOURNAL")" "114"
rec_clean_deletes="$(hop_deletes "$HOP_JOURNAL")"
# Record mode must PREDICT the directory removal, and must word it as a forecast
# — a write failure it cannot foresee can still invalidate it.
check "record mode predicts the directory removal" \
  "grep -q \$'^delete\t.claude/bin/test/\tdirectory would be emptied and removed$' '$HOP_JOURNAL'"
check "record mode never asserts the removal completed" \
  "! grep -q \$'\tdirectory emptied and removed$' '$HOP_JOURNAL'"
fixture_cleanup "$w"

# --- act mode on a CLEAN tree: the real 0.3.0 hop's normal case -------------
# Nothing of the operator's under the prefix, so the directory itself goes.
# .claude/bin/test/ is ~230 nested directories: a single rmdir on the top can
# never succeed, and ending the function on its status returned 1 from the
# happy path — which would abort a hop guarded by `hop_rm_owned … || return`.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
hop_ops_init "$p" "$mf" 0
hop_rm_owned .claude/bin/test; clean_rc=$?
eq "hop_rm_owned returns 0 on a clean tree" "$clean_rc" "0"
check "hop_rm_owned removed the emptied directory" "[ ! -d '$p/.claude/bin/test' ]"
check "hop_rm_owned left the sibling validators alone" "[ -d '$p/.claude/bin' ]"
check "the directory-removal claim is true, not aspirational" \
  "grep -q \$'^delete\t.claude/bin/test/\tdirectory emptied and removed$' '$HOP_JOURNAL'"
act_clean_deletes="$(hop_deletes "$HOP_JOURNAL")"
eq "act mode on a clean tree deleted all 114 shipped files" "$act_clean_deletes" "114"
eq "act and record agree on the deletion count for the same tree" \
  "$act_clean_deletes" "$rec_clean_deletes"
fixture_cleanup "$w"

# --- record mode on the SAME tree act mode modified ------------------------
# Fidelity, stated directly: given identical input, record mode's prediction
# must match what act mode did — including that it does NOT predict removing
# a directory still holding a file the operator edited.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
hop_ops_init "$p" "$mf" 1
printf 'mine\n' > "$p/.claude/bin/test/my-fixture.sh"
printf '\nMY EDIT\n' >> "$p/$edited_rel"
rec_dirty_before="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
hop_rm_owned .claude/bin/test; dirty_rc=$?
eq "record mode returns 0 too" "$dirty_rc" "0"
eq "record mode predicts act mode's deletion count exactly" \
  "$(hop_deletes "$HOP_JOURNAL")" "$act_deletes"
eq "record mode still wrote nothing" \
  "$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)" \
  "$rec_dirty_before"
check "record mode does not predict removing a directory that must stay" \
  "! grep -q \$'^delete\t.claude/bin/test/\t' '$HOP_JOURNAL'"
eq "record mode labels exactly one file as the operator's own" \
  "$(awk -F'\t' '$3 ~ /not shipped by INSPIRE/' "$HOP_JOURNAL" | wc -l | tr -d ' ')" "1"

# The nesting refusal must fire in record mode too, so a preview surfaces a
# broken hop before anything is touched — a refusal only act mode can discover
# is a refusal that arrives too late.
mkdir -p "$p/.claude/nest-src" "$p/.inspire/nest-dst/payload"
printf 'PAYLOAD\n' > "$p/.claude/nest-src/payload"
rec_j_before="$(wc -l < "$HOP_JOURNAL" | tr -d ' ')"
hop_mv .claude/nest-src/payload .inspire/nest-dst/payload 2>/dev/null
eq "record mode refuses the nesting move too" "$?" "1"
eq "the record-mode refusal journals nothing either" \
  "$(wc -l < "$HOP_JOURNAL" | tr -d ' ')" "$rec_j_before"
fixture_cleanup "$w"

# --- a prefix that was NEVER THERE gets no directory verdict at all ---------
# Reached the ordinary way: the operator deleted .claude/bin/test/ by hand before
# upgrading. With nothing under the prefix the "the directory can go" predicate
# is trivially satisfied, so both modes journalled an outcome for it — record
# mode "directory would be emptied and removed", act mode the past-tense
# "directory emptied and removed". Neither happened; there was no directory.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
rm -rf "$p/.claude/bin/test"
check "premise: the prefix really is absent" "[ ! -e '$p/.claude/bin/test' ]"
dirverdicts() { awk -F'\t' '$2==".claude/bin/test/"' "$1" | wc -l | tr -d ' '; }
unset HOP_JOURNAL
hop_ops_init "$p" "$mf" 0
hop_rm_owned .claude/bin/test; absent_rc=$?
eq "hop_rm_owned on an absent prefix returns 0" "$absent_rc" "0"
eq "act mode says nothing about a directory that never existed" \
  "$(dirverdicts "$HOP_JOURNAL")" "0"
check "act mode never claims it was emptied and removed" \
  "! grep -q 'directory emptied and removed' '$HOP_JOURNAL'"
unset HOP_JOURNAL
hop_ops_init "$p" "$mf" 1
hop_rm_owned .claude/bin/test
eq "record mode forecasts nothing about it either" \
  "$(dirverdicts "$HOP_JOURNAL")" "0"
check "record mode never forecasts emptying it" \
  "! grep -q 'directory would be emptied' '$HOP_JOURNAL'"
fixture_cleanup "$w"

# ---- the journal must never claim a mutation that failed -------------------
# The journal IS the operator's report, and nothing downstream cross-checks it
# against disk, so a line written BEFORE the mutation is a claim we cannot
# support. chmod 555 on the parent makes rm/mv fail while the paths survive —
# the same shape as a read-only mount, an immutable flag, or a full disk.
# Literal /tmp paths throughout, and the mode is restored before cleanup.
rm -rf /tmp/inspire-hopops-perm
mkdir -p /tmp/inspire-hopops-perm/locked
perm=/tmp/inspire-hopops-perm
printf 'a\n' > "$perm/locked/a.txt"
printf 'b\n' > "$perm/locked/b.txt"
printf 'victim\n' > "$perm/locked/victim.txt"
jq -n --arg a "$(sha256_of "$perm/locked/a.txt")" --arg b "$(sha256_of "$perm/locked/b.txt")" \
  '{version:"9.9.9",released:"x",commit:"x",layout:"A",
    files:{"locked/a.txt":$a,"locked/b.txt":$b}}' > "$perm/mf.json"
chmod 555 "$perm/locked"
# `touch`, not `: >` — a redirection failure is reported by the shell itself and
# cannot be silenced with 2>/dev/null on the command.
if touch "$perm/locked/probe" 2>/dev/null; then
  rm -f "$perm/locked/probe"
  skipped 19 "permission-failure journalling — writable despite chmod 555 (running as root?)"
else
  HOP_JOURNAL="$perm/j1"; hop_ops_init "$perm" "$perm/mf.json" 0
  perm_err="$(hop_rm locked/victim.txt 2>&1 >/dev/null)"; perm_rc=$?
  eq "a failed hop_rm returns non-zero" "$perm_rc" "1"
  check "a failed hop_rm journals NO delete line" "! grep -q \$'^delete\t' '$perm/j1'"
  check "a failed hop_rm journals keep with the reason" \
    "grep -q \$'^keep\tlocked/victim.txt\tcould not be removed' '$perm/j1'"
  check "a failed hop_rm leaks no raw rm error" \
    "! printf '%s' \"\$perm_err\" | grep -q '^rm:'"
  check "a failed hop_rm explains itself as INSPIRE" \
    "printf '%s' \"\$perm_err\" | grep -q 'INSPIRE: could not delete'"
  check "the file hop_rm failed on is still on disk" "[ -f '$perm/locked/victim.txt' ]"

  # The severe case: the per-file rm had no error check at all, so this
  # returned 0 and journalled two deletes while removing nothing.
  HOP_JOURNAL="$perm/j2"; hop_ops_init "$perm" "$perm/mf.json" 0
  hop_rm_owned locked 2>/dev/null; perm_rc2=$?
  eq "hop_rm_owned propagates a failed file deletion" "$perm_rc2" "1"
  check "hop_rm_owned journals NO delete it did not perform" \
    "! grep -q \$'^delete\t' '$perm/j2'"
  eq "hop_rm_owned journals a keep-with-reason per failed file" \
    "$(awk -F'\t' '$3 ~ /^could not be removed/' "$perm/j2" | wc -l | tr -d ' ')" "2"
  check "both shipped files hop_rm_owned failed on are still on disk" \
    "[ -f '$perm/locked/a.txt' ] && [ -f '$perm/locked/b.txt' ]"

  HOP_JOURNAL="$perm/j3"; hop_ops_init "$perm" "$perm/mf.json" 0
  hop_mv locked/a.txt moved/a.txt 2>/dev/null
  eq "a failed hop_mv returns non-zero" "$?" "1"
  check "a failed hop_mv journals NO move line" "! grep -q \$'^move\t' '$perm/j3'"
  check "a failed hop_mv journals keep with the reason" \
    "grep -q \$'^keep\tlocked/a.txt\tcould not be moved' '$perm/j3'"

  # Act vs record where the deletion WILL fail. `failed_n` is act-mode-only and
  # structurally unpredictable — knowing whether rm succeeds needs a write, and
  # record mode writes nothing. So record mode is allowed to be optimistic, but
  # it must word its verdict as a FORECAST and must never assert completion.
  # A prefix holding only manifest-listed files, so nothing else blocks removal.
  mkdir -p "$perm/only"
  printf 'a\n' > "$perm/only/a.txt"
  printf 'b\n' > "$perm/only/b.txt"
  jq -n --arg a "$(sha256_of "$perm/only/a.txt")" --arg b "$(sha256_of "$perm/only/b.txt")" \
    '{version:"9.9.9",released:"x",commit:"x",layout:"A",
      files:{"only/a.txt":$a,"only/b.txt":$b}}' > "$perm/mf-only.json"
  chmod 555 "$perm/only"

  HOP_JOURNAL="$perm/j-rec"; hop_ops_init "$perm" "$perm/mf-only.json" 1
  hop_rm_owned only 2>/dev/null; only_rec_rc=$?
  HOP_JOURNAL="$perm/j-act"; hop_ops_init "$perm" "$perm/mf-only.json" 0
  hop_rm_owned only 2>/dev/null; only_act_rc=$?

  eq "record mode returns 0 where it cannot foresee the failure" "$only_rec_rc" "0"
  eq "act mode returns non-zero when the deletion really fails" "$only_act_rc" "1"
  check "record mode's optimistic verdict is worded as a forecast" \
    "grep -q \$'^delete\tonly/\tdirectory would be emptied and removed$' '$perm/j-rec'"
  check "record mode never asserts a removal it cannot guarantee" \
    "! grep -q \$'\tdirectory emptied and removed$' '$perm/j-rec'"
  check "act mode reports the truth: the directory stayed" \
    "grep -q \$'^keep\tonly/\tdirectory left in place — files in it could not be removed$' '$perm/j-act'"
  check "act mode journals no directory deletion it did not perform" \
    "! grep -q \$'^delete\tonly/' '$perm/j-act'"
  chmod 755 "$perm/only"
fi
chmod 755 /tmp/inspire-hopops-perm/locked
rm -rf /tmp/inspire-hopops-perm

# ---- a symlink is a directory entry, so both modes must see it -------------
# `find -type f` excluded it, so both modes computed zero survivors; only act
# mode then discovered via rmdir that the directory was not empty. The two
# modes returned OPPOSITE verdicts on identical input, and neither mentioned
# the symlink at all. `! -type d` fixes both halves at once.
rm -rf /tmp/inspire-hopops-link
mkdir -p /tmp/inspire-hopops-link/proj/pfx/nested
sym=/tmp/inspire-hopops-link
printf 'x\n' > "$sym/proj/pfx/nested/ours.txt"
jq -n --arg h "$(sha256_of "$sym/proj/pfx/nested/ours.txt")" \
  '{version:"9.9.9",released:"x",commit:"x",layout:"A",
    files:{"pfx/nested/ours.txt":$h}}' > "$sym/mf.json"
ln -s /nonexistent-target-xyz "$sym/proj/pfx/operator-symlink"
eq "the symlink is invisible to -type f but seen by ! -type d" \
  "$(find "$sym/proj/pfx" -type f | wc -l | tr -d ' ')/$(find "$sym/proj/pfx" ! -type d | wc -l | tr -d ' ')" \
  "1/2"

HOP_JOURNAL="$sym/j-act"; hop_ops_init "$sym/proj" "$sym/mf.json" 0
hop_rm_owned pfx
sym_act="$(awk -F'\t' '$2=="pfx/" {print $1}' "$sym/j-act")"
sym_act_link="$(grep -c 'operator-symlink' "$sym/j-act")"

# Rebuild an identical starting tree for record mode.
rm -rf /tmp/inspire-hopops-link/proj
mkdir -p /tmp/inspire-hopops-link/proj/pfx/nested
printf 'x\n' > "$sym/proj/pfx/nested/ours.txt"
ln -s /nonexistent-target-xyz "$sym/proj/pfx/operator-symlink"
HOP_JOURNAL="$sym/j-rec"; hop_ops_init "$sym/proj" "$sym/mf.json" 1
hop_rm_owned pfx
sym_rec="$(awk -F'\t' '$2=="pfx/" {print $1}' "$sym/j-rec")"
sym_rec_link="$(grep -c 'operator-symlink' "$sym/j-rec")"

eq "act and record agree on the directory verdict with a symlink present" \
  "$sym_act" "$sym_rec"
eq "the verdict is keep — a symlink blocks the removal" "$sym_act" "keep"
eq "act mode reports the operator's symlink" "$sym_act_link" "1"
eq "record mode reports the operator's symlink" "$sym_rec_link" "1"
check "the symlink is labelled the operator's, not ours" \
  "grep -q \$'^keep\tpfx/operator-symlink\tyours' '$sym/j-rec'"
check "the operator's symlink was not deleted" \
  "[ -L '$sym/proj/pfx/operator-symlink' ]"
rm -rf /tmp/inspire-hopops-link

# ---- the chain ----------------------------------------------------------
. "$PLUGIN_ROOT/scripts/lib/chain.sh"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
# Operator artefacts that must survive the hop.
printf 'mine\n' > "$p/.claude/bin/test/my-fixture.sh"
printf 'mine\n' > "$p/.claude/bin/my-own-script.sh"
mkdir -p "$p/.claude/skills/inspire-code/references"
printf 'go rules\n' > "$p/.claude/skills/inspire-code/references/go-best-practices.md"
printf 'edited staging\n' >> "$p/.inspire/skills/inspire-domain/SKILL.md"
kb_before="$(find "$p/.inspire_kb" -type f | wc -l | tr -d ' ')"

# hop_ops_init reuses an already-set $HOP_JOURNAL rather than minting a fresh
# one (that is what lets the permission-failure block above pin it to a
# specific path across several calls). The symlink section just deleted the
# directory its own $HOP_JOURNAL pointed into, so that stale path is still
# sitting in the variable — unset it here so hop_ops_init falls through to
# `mktemp` instead of truncating a path whose parent no longer exists.
unset HOP_JOURNAL
hop_ops_init "$p" "$PLUGIN_ROOT/manifests/0.2.1.json" 0
run_chain "$PLUGIN_ROOT" 0.2.1 0.4.0
eq "chain exit status" "$?" "0"

check "KB moved to inspire_kb"          "[ -d '$p/inspire_kb' ]"
check "old KB root is gone"             "[ ! -d '$p/.inspire_kb' ]"
eq    "KB file count unchanged" \
      "$(find "$p/inspire_kb" -type f | wc -l | tr -d ' ')" "$kb_before"
check "validators moved to .inspire/bin" "[ -f '$p/.inspire/bin/review.sh' ]"
check "hooks moved to .claude/inspire/hooks" \
      "[ -f '$p/.claude/inspire/hooks/session-start.sh' ]"
check "shipped fixtures removed"        "[ ! -e '$p/.claude/bin/test/run-tests.sh' ]"
check "operator fixture survived"       "[ -f '$p/.claude/bin/test/my-fixture.sh' ]"
check "operator script in .claude/bin survived" \
      "[ -f '$p/.claude/bin/my-own-script.sh' ]"
check "project-authored reference survived in place" \
      "[ -f '$p/.claude/skills/inspire-code/references/go-best-practices.md' ]"
check "0.2 staging source was NOT deleted" "[ -d '$p/.inspire/skills' ]"
check "0.2 staging templates were NOT deleted" "[ -d '$p/.inspire/templates' ]"
check "staged skill edit preserved byte-for-byte" \
      "grep -q 'edited staging' '$p/.inspire/skills/inspire-domain/SKILL.md'"
check "install.sh removed"              "[ ! -e '$p/.inspire/install.sh' ]"
check "staging source reported"         "grep -q 'staging source' '$HOP_JOURNAL'"
check "unregister queued"               "grep -q 'unregister' '$HOP_JOURNAL'"

# Re-running the chain must converge, not fail.
run_chain "$PLUGIN_ROOT" 0.2.1 0.4.0
eq "chain is re-runnable" "$?" "0"
check "re-run left the KB alone" "[ -d '$p/inspire_kb' ]"
fixture_cleanup "$w"

# A 0.3 project has no hops to run.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
unset HOP_JOURNAL
hop_ops_init "$p" "$PLUGIN_ROOT/manifests/0.3.1.json" 0
run_chain "$PLUGIN_ROOT" 0.3.1 0.4.0
eq "0.3.1 → 0.4.0 runs no hops" "$(grep -c . "$HOP_JOURNAL" || true)" "0"
fixture_cleanup "$w"

# ---- the three-way classifier -------------------------------------------
. "$PLUGIN_ROOT/scripts/lib/merge.sh"
MAP_03="$(layout_map "$PLUGIN_ROOT" 0.3)"
MAP_PRE="$(layout_map "$PLUGIN_ROOT" pre-0.3)"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
mf="$PLUGIN_ROOT/manifests/0.3.1.json"
base="$PLUGIN_ROOT/base"

verdict_for() { printf '%s' "$1" | awk -F'\t' -v t="$2" '$2==t{print $1; exit}'; }
# A content fingerprint of the whole project: path + hash of every file. classify
# must leave this byte-identical — it is the only assertion that actually proves
# "writes nothing" (a per-file existence check cannot see a rewrite).
tree_print() { ( cd "$1" && find . -type f | LC_ALL=C sort \
                 | while IFS= read -r f; do printf '%s %s\n' "$f" "$(sha256_of "$f")"; done ); }

# Row: they didn't change it, we didn't change it → noop.
# Row: they changed it, we didn't → keep.
printf '\nMY EDIT\n' >> "$p/.inspire/bin/no-todos.sh"
# Row: they deleted an owned file → restore.
rm -f "$p/.inspire/bin/acyclic-deps.sh"
# Row: project-authored file inside an owned dir → keep. THE rm -rf REGRESSION.
printf 'go rules\n' > "$p/.claude/skills/inspire-code/references/go-best-practices.md"

before="$(tree_print "$p")"
out="$(classify "$mf" "$p" "$base" "$MAP_03" "$MAP_03")"
after="$(tree_print "$p")"

eq "unmodified file is a no-op" \
   "$(verdict_for "$out" .inspire/bin/review.sh)" "noop"
eq "operator edit is kept" \
   "$(verdict_for "$out" .inspire/bin/no-todos.sh)" "keep"
eq "operator deletion is restored" \
   "$(verdict_for "$out" .inspire/bin/acyclic-deps.sh)" "restore"
eq "project-authored file is kept" \
   "$(verdict_for "$out" .claude/skills/inspire-code/references/go-best-practices.md)" "keep"
check "classify wrote nothing" "[ -f '$p/.inspire/bin/no-todos.sh' ]"
check "classify did not restore anything itself" \
   "[ ! -e '$p/.inspire/bin/acyclic-deps.sh' ]"
eq "classify left the whole tree byte-identical" "$before" "$after"

# keepset_of: hashes, not paths — every keep plus every unresolved ask.
vf="$w/verdicts.tsv"; printf '%s\n' "$out" > "$vf"
ks="$(keepset_of "$vf" "$p")"
check "keepset carries the operator's edited validator" \
   "printf '%s\n' \"\$ks\" | grep -Fxq \"\$(sha256_of '$p/.inspire/bin/no-todos.sh')\""
check "keepset carries the project-authored file" \
   "printf '%s\n' \"\$ks\" | grep -Fxq \"\$(sha256_of '$p/.claude/skills/inspire-code/references/go-best-practices.md')\""
check "keepset does not carry an untouched shipped file" \
   "! printf '%s\n' \"\$ks\" | grep -Fxq \"\$(sha256_of '$p/.inspire/bin/review.sh')\""
check "keepset is deduplicated and hash-shaped" \
   "[ -z \"\$(printf '%s\n' \"\$ks\" | grep -vE '^[0-9a-f]{64}\$')\" ]"
fixture_cleanup "$w"

# --- staleness and conflict, on a PRE-0.3 source -------------------------
# NOTE: do not use a 0.3.0 fixture for staleness. plugin/base/ is byte-identical
# between 0.3.0 and 0.3.1 (the hotfix touched only materialize.sh, the skills
# and the tests), so a 0.3.0 project has NOTHING stale and the assertion would
# fail for a reason unrelated to the code. 0.2.1's base genuinely differs.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
mf21="$PLUGIN_ROOT/manifests/0.2.1.json"
out="$(classify "$mf21" "$p" "$base" "$MAP_PRE" "$MAP_03")"

check "a pre-0.3 source finds its base counterparts (nothing wholesale-deleted)" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"delete\" && \$2 !~ /^\.claude\/bin\/test\//' | wc -l | tr -d ' ')\" -lt 20 ]"
check "the validator set is NOT mass-classified as delete" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"delete\" && \$2 ~ /^\.claude\/bin\/[^\/]*\$/' | wc -l | tr -d ' ')\" = 0 ]"
check "at least one untouched-but-stale file is replaced" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"replace\"' | wc -l | tr -d ' ')\" -ge 1 ]"
check "the dropped bin/test fixtures are recognised as ours to delete" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"delete\" && \$2 ~ /^\.claude\/bin\/test\//' | wc -l | tr -d ' ')\" = 114 ]"
check "a file that only MOVED is not reported as a creation" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"create\" && \$2==\".inspire/bin/review.sh\"' | wc -l | tr -d ' ')\" = 0 ]"

# A genuine conflict: they edited a file that also changed upstream.
stale="$(printf '%s' "$out" | awk -F'\t' '$1=="replace"{print $2; exit}')"
check "a stale path was found to conflict on" "[ -n '$stale' ]"
printf '\nMY EDIT\n' >> "$p/$stale"
out2="$(classify "$mf21" "$p" "$base" "$MAP_PRE" "$MAP_03")"
eq "both-changed is a conflict" "$(verdict_for "$out2" "$stale")" "ask"
fixture_cleanup "$w"

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
same_file() { [ "$(sha256_of "$1")" = "$(sha256_of "$2")" ]; }
# Fast whole-tree fingerprint (path + content of every file). tree_print above
# spawns a process per file, which is too slow for a 935-file 0.2.1 fixture.
if command -v sha256sum >/dev/null 2>&1; then SHA_CMD="sha256sum"; else SHA_CMD="shasum -a 256"; fi
tree_hash() {
  local t; t="$(mktemp)"
  ( cd "$1" && find . -type f | LC_ALL=C sort | tr '\n' '\0' | xargs -0 $SHA_CMD ) > "$t" 2>/dev/null
  sha256_of "$t"; rm -f "$t"
}
# Octal mode, portably enough for the two platforms this suite runs on.
mode_of() {
  case "$(uname -s)" in Darwin*|*BSD*) stat -f '%Lp' "$1" ;; *) stat -c '%a' "$1" ;; esac
}

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

# ---- the grouped report -------------------------------------------------
. "$PLUGIN_ROOT/scripts/lib/report.sh"

j="$(mktemp)"; v="$(mktemp)"
printf 'move\t.claude/bin/review.sh\t.inspire/bin/review.sh\n'      >> "$j"
printf 'delete\t.claude/bin/test/run-tests.sh\t\n'                  >> "$j"
printf 'keep\t.claude/bin/test/my-fixture.sh\tyours\n'              >> "$j"
printf 'move\t.inspire_kb\tinspire_kb\n'                            >> "$j"
printf 'report\t\t.manual/ came from the fork\n'                    >> "$j"
printf 'replace\t.claude/skills/inspire-domain/SKILL.md\tstale\n'   >> "$v"
printf 'ask\t.claude/skills/inspire-task/SKILL.md\tboth changed\n'  >> "$v"
printf 'create\tinspire_kb/07_x/README.md\tnew\n'                   >> "$v"

out="$(render_report 0.2.1 0.4.0 "$j" "$v" 1 2>&1)"

check "report announces the dry run"  "printf '%s' \"\$out\" | grep -q 'DRY RUN'"
check "report shows the chain"        "printf '%s' \"\$out\" | grep -q '0.2.1 → 0.4.0'"
check "report has a RUNTIME group"    "printf '%s' \"\$out\" | grep -q 'RUNTIME'"
check "report has a KNOWLEDGE BASE group" \
      "printf '%s' \"\$out\" | grep -q 'KNOWLEDGE BASE'"
check "report has a LEFT ALONE group" "printf '%s' \"\$out\" | grep -q 'LEFT ALONE'"
check "report flags the decision"     "printf '%s' \"\$out\" | grep -q 'ASK'"
check "report counts the decision"    "printf '%s' \"\$out\" | grep -q '1 decision'"
check "report carries the superset caveat" \
      "printf '%s' \"\$out\" | grep -qi 'already absent'"
check "KB move lands in the KB group" \
      "printf '%s' \"\$out\" | awk '/KNOWLEDGE BASE/,/^\$/' | grep -q 'inspire_kb'"
rm -f "$j" "$v"

# A path outside .claude/*, .inspire/*, inspire_kb and the harness literals
# (source/, prototype/, root CLAUDE.md) is real product-space, not a catch-all
# to drop: _group_of buckets it as `product`, and render_report must give that
# bucket its own section, or the footer's tallies describe lines the operator
# is never shown at all.
pj="$(mktemp)"; pv="$(mktemp)"
printf 'delete\tsource/README.md\tstale product-space file\n' >> "$pj"
printf 'ask\tCLAUDE.md\tboth changed\n'                        >> "$pv"
pout="$(render_report 0.2.1 0.4.0 "$pj" "$pv" 0 2>&1)"
check "a product-space file is rendered in the body, not just tallied in the footer" \
      "printf '%s' \"\$pout\" | grep -q 'PRODUCT' && \
       printf '%s' \"\$pout\" | grep -q 'source/README.md' && \
       printf '%s' \"\$pout\" | grep -q 'CLAUDE.md' && \
       printf '%s' \"\$pout\" | grep -q '1 decision'"
rm -f "$pj" "$pv"

# The two streams legitimately describe the same paths, and the report merged
# them raw: the hop journals `delete` for each of the 114 pre-0.3 fixtures it
# removes and classify independently reaches `delete` for the same 114, so a
# clean v0.2.1 fixture read "232 deletions" where 118 paths are deleted, across
# 306 body lines of which 230 were about one prefix. The footer is the number an
# operator judges the risk by. Same verb + same path is ONE fact: render once,
# count once. Two DIFFERENT verbs on one path are two facts and both must stay.
dj="$(mktemp)"; dv="$(mktemp)"
printf 'delete\t.claude/bin/test/run-tests.sh\t\n'                          >> "$dj"
printf 'move\t.claude/bin/review.sh\t.inspire/bin/review.sh\n'              >> "$dj"
printf 'unregister\t.claude/hooks/\tretire stale hook registration\n'       >> "$dj"
printf 'report\t\tfirst note\n'                                             >> "$dj"
printf 'report\t\tsecond note\n'                                            >> "$dj"
printf 'delete\t.claude/bin/test/run-tests.sh\tno longer part of INSPIRE\n' >> "$dv"
printf 'replace\t.claude/bin/review.sh\tuntouched, takes the new version\n' >> "$dv"
dout="$(render_report 0.2.1 0.4.0 "$dj" "$dv" 1 2>&1)"

eq "a path both halves delete is rendered once, not twice" \
   "$(printf '%s' "$dout" | grep -c 'run-tests.sh')" "1"
eq "the surviving line is the hop's, which performed the deletion" \
   "$(printf '%s' "$dout" | grep -c 'no longer part of INSPIRE')" "0"
eq "two different verbs on one path stay two lines" \
   "$(printf '%s' "$dout" | grep -c 'review.sh')" "2"
check "the footer counts unique paths per verb, and tallies replace" \
   "printf '%s' \"\$dout\" | grep -q '1 moves · 1 replacements · 1 deletions'"
check "the footer tallies unregister too" \
   "printf '%s' \"\$dout\" | grep -q '1 hook registration(s) retired'"
# A `report` note has NO path, so a verb+path key would collapse every note into
# the first one. Path-less lines are exempt from de-duplication for that reason.
check "path-less notes are exempt from de-duplication" \
   "printf '%s' \"\$dout\" | grep -q 'first note' && printf '%s' \"\$dout\" | grep -q 'second note'"
rm -f "$dj" "$dv"

# ---- --mode plan --------------------------------------------------------
MZ="$PLUGIN_ROOT/scripts/materialize.sh"
target="$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
before="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
out="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>/dev/null)"
rc=$?
after="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"

eq "plan exits 0"                "$rc" "0"
eq "plan wrote nothing"          "$before" "$after"
eq "plan detected 0.2.1"         "$(printf '%s' "$out" | jq -r .source_version)" "0.2.1"
eq "plan targets the plugin"     "$(printf '%s' "$out" | jq -r .target_version)" "$target"
eq "plan names the pre-0.3 layout" "$(printf '%s' "$out" | jq -r .layout)" "pre-0.3"
check "plan lists the 0.3.0 hop" \
  "[ \"\$(printf '%s' \"\$out\" | jq -r '.chain|index(\"0.3.0\")')\" != null ]"
check "plan counts verdicts" \
  "[ \"\$(printf '%s' \"\$out\" | jq -r '.verdicts.replace')\" -ge 0 ]"
# The counts are a tally over the MERGED stream (hop journal + verdicts), not
# verdicts alone: on this pre-0.3 fixture the 0.3.0 hop journals 114 bin/test
# deletions in record mode, which classify alone could never produce. This pins
# "the JSON agrees with the stderr footer" with no 0.7.0 hop needed.
check "plan's delete count includes the hop journal (>= 114)" \
  "[ \"\$(printf '%s' \"\$out\" | jq -r '.verdicts.delete')\" -ge 114 ]"
fixture_cleanup "$w"

# A pre-0.3 project must no longer be refused.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "pre-0.3 is planned, not refused" "$?" "0"
fixture_cleanup "$w"

# Never downgrade.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
fake="$(mktemp -d)"; cp -R "$PLUGIN_ROOT/." "$fake/plugin"
jq '.version="0.1.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" > "$fake/plugin/.claude-plugin/plugin.json"
bash "$MZ" --mode plan --plugin-root "$fake/plugin" --project-root "$p" >/dev/null 2>&1
eq "a downgrade is refused" "$?" "1"
rm -rf "$fake"; fixture_cleanup "$w"

# ---- plan and the resolution flags --------------------------------------
# Plan predicts the UNRESOLVED split, so it refuses the flags rather than honour
# them in one half of the run and not the other: run_plan never calls
# _apply_resolutions, so a --take-base the classify half ignored while a hop
# consulted it would put two answers in one JSON document.
#
# The pair matters together. The arrays are legitimately EMPTY on every plan
# run, and under `set -u` on bash 3.2 a bare "${ARR[@]}" expansion of an empty
# array aborts the shell outright (the ${#ARR[@]} form the guard uses today is
# safe) — so the flagless run is asserted first, on the newest layout, as the
# standing regression guard for any future edit that touches how the arrays are
# read.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
plan_out="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>/dev/null)"
eq "plan with no resolution flags exits 0" "$?" "0"
check "plan with no resolution flags still emits its JSON" \
  "printf '%s' \"\$plan_out\" | jq -e '.ask|type==\"array\"' >/dev/null"

rej_err="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" \
             --take-base .claude/skills/inspire-domain/SKILL.md 2>&1 >/dev/null)"
eq "plan rejects --take-base (rc)" "$?" "1"
check "plan's rejection says why, and where the flag belongs" \
  "printf '%s' \"\$rej_err\" | grep -q 'UNRESOLVED' && printf '%s' \"\$rej_err\" | grep -q 'mode update --dry-run'"
bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" \
     --take-mine .claude/skills/inspire-domain/SKILL.md >/dev/null 2>&1
eq "plan rejects --take-mine too" "$?" "1"
bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" \
     --skip .claude/skills/inspire-domain/SKILL.md >/dev/null 2>&1
eq "plan rejects the deprecated --skip alias as well" "$?" "1"
fixture_cleanup "$w"

# ---- a failed hop must propagate, and must never stamp the version ---------
# `. "$hop" || return 2` CANNOT see this: a sourced script's exit status is its
# LAST command's, and hops/0.3.0.sh ends with hop_report, which always returns 0.
# So run_chain returned 0 whatever happened in the middle and run_materialize's
# `|| exit 2` was dead code. Reproduced with .claude/bin unwritable: all 14
# validator moves failed, every failure was honestly journalled, the run exited
# 0 — and .inspire.lock went 0.2.1 → 0.3.1, claiming a migration that did not
# happen. HOP_FAILED, compared across each hop, is what makes it observable.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
chmod 500 "$p/.claude/bin"
if touch "$p/.claude/bin/probe" 2>/dev/null; then
  rm -f "$p/.claude/bin/probe"; chmod 755 "$p/.claude/bin"
  skipped 7 "hop-failure propagation — .claude/bin writable despite chmod 500 (running as root?)"
  fixture_cleanup "$w"
else
  unset HOP_JOURNAL
  hop_ops_init "$p" "$PLUGIN_ROOT/manifests/0.2.1.json" 0
  run_chain "$PLUGIN_ROOT" 0.2.1 0.4.0 >/dev/null 2>&1
  eq "run_chain returns 2 when an operation inside a hop fails" "$?" "2"
  check "the failure counter saw every failed move" "[ \"\${HOP_FAILED:-0}\" -ge 14 ]"
  eq "the journal still records each failure honestly" \
     "$(awk -F'\t' '$1=="keep" && $3 ~ /^could not be moved/' "$HOP_JOURNAL" | wc -l | tr -d ' ')" "14"
  check "no move it could not perform is claimed as done" \
     "! grep -q \$'^move\t.claude/bin/' '$HOP_JOURNAL'"
  chmod 755 "$p/.claude/bin"
  fixture_cleanup "$w"

  # End to end: exit 2, and the lock still reads the OLD version. A stale lock is
  # recoverable — the next run re-detects 0.2.1 and re-runs the hop; a lock that
  # claims 0.3.1 would make detection score the project as already migrated and
  # the migration would never be retried.
  w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
  chmod 500 "$p/.claude/bin"
  hf_err="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1 >/dev/null)"
  hf_rc=$?
  chmod 755 "$p/.claude/bin"
  eq "a failed hop makes --mode update exit 2" "$hf_rc" "2"
  eq "a failed hop does NOT stamp the new version into the lock" \
     "$(jq -r .inspire_version "$p/.inspire.lock")" "0.2.1"
  check "the failure is explained and re-running is named as the recovery" \
     "printf '%s' \"\$hf_err\" | grep -q 'did not complete' && \
      printf '%s' \"\$hf_err\" | grep -q 'run the update again'"
  fixture_cleanup "$w"
fi

# Record mode can fail too, and --mode plan must check it: hop_mv refuses in BOTH
# modes when the destination is a directory (the move would nest the source
# inside it). A plan that logged that and carried on would forecast a migration
# the real run refuses to perform.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
rm -f "$p/.inspire/bin/review.sh"; mkdir -p "$p/.inspire/bin/review.sh"
planfail_before="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
pf_err="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1 >/dev/null)"
pf_rc=$?
eq "a hop refusal in record mode makes --mode plan exit 2" "$pf_rc" "2"
eq "the refused plan still wrote nothing" \
   "$planfail_before" \
   "$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
check "the plan says why it stopped" \
   "printf '%s' \"\$pf_err\" | grep -q 'refused an operation'"
fixture_cleanup "$w"

# ---- end to end: 0.2.1 → current ---------------------------------------
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
printf 'mine\n' > "$p/.claude/bin/test/my-fixture.sh"
mkdir -p "$p/.claude/skills/inspire-code/references"
printf 'go rules\n' > "$p/.claude/skills/inspire-code/references/go-best-practices.md"
printf '\nMY EDIT\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
mine_hash="$(shasum -a 256 "$p/.claude/skills/inspire-domain/SKILL.md" | awk '{print $1}')"

# seed_kb must run on UPGRADE, not just init — a 0.2 project has to finally
# receive the KB layers and files added since. Proving that needs care: 0.2.1's
# 21-file skeleton covers nearly all of today's 17-file base/kb (0.7.0 stopped
# shipping the three _index.md seeds and the two _template.md seeds, and added
# 05_screens/components/.gitkeep to keep the emptied directory shipping:
# 21 − 5 + 1 = 17; glossary.md arrives later in this release, making 18), so
# the hop's `mv .inspire_kb inspire_kb` alone satisfies "every skeleton file
# is present" for everything but that .gitkeep. Remove one whole layer and one
# file inside a layer that stays, so only a seed can put them back.
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

# Re-running converges.
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "update is re-runnable" "$?" "0"
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

# ---- end to end: 0.1.0 → current, the longest chain there is ---------------
# The tree the blind verification actually ran on. Three findings came out of it,
# all of them empty containers a clean install never creates:
#   A2 .claude/bin/                     — drained by 14 hop_mv, never pruned
#   A3 .claude/hooks/                   — drained by 3 hop_mv, never pruned
#   A4 .claude/skills/inspire-learn/    — a 0.1-only skill whose files pass 2
#                                         removed, leaving the container (0.1 is
#                                         the only release that shipped it, so
#                                         no other fixture reproduces A4 at all)
# and one process finding: nothing about the migration persisted anywhere, so
# afterwards there was no way to tell what it had done (§6).
w="$(mktemp -d)"; p="$(fixture_from_tag v0.1.0 "$w" "$REPO")"
check "premise: 0.1.0 shipped the inspire-learn skill" \
  "[ -f '$p/.claude/skills/inspire-learn/SKILL.md' ] && \
   [ -f '$p/.claude/skills/inspire-learn/references/learnings-format.md' ]"
e2e1_bin="$(find "$p/.claude/bin" -maxdepth 1 -type f | wc -l | tr -d ' ')"
eq "premise: 0.1.0 staged 14 validators under .claude/bin" "$e2e1_bin" "14"
e2e1_err="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1 >/dev/null)"
eq "0.1.0 → current exits 0" "$?" "0"

check "A2: no empty .claude/bin survives"   "[ ! -e '$p/.claude/bin' ]"
check "A3: no empty .claude/hooks survives" "[ ! -e '$p/.claude/hooks' ]"
check "A4: no empty inspire-learn survives" "[ ! -e '$p/.claude/skills/inspire-learn' ]"

# The pruning must not have cost anything the migration exists to deliver.
eq "all 14 validators + the trust tool landed at .inspire/bin" \
   "$(find "$p/.inspire/bin" -maxdepth 1 -type f | wc -l | tr -d ' ')" "15"
check "the relocated hooks are all three there" \
   "[ -f '$p/.claude/inspire/hooks/session-start.sh' ] && \
    [ -f '$p/.claude/inspire/hooks/pre-commit.sh' ] && \
    [ -f '$p/.claude/inspire/hooks/pre-pr.sh' ]"
# hops/0.3.0.sh declares these NOT deleted — they may hold un-reinstalled edits.
check "the pre-0.3 staging source is preserved" \
   "[ -d '$p/.inspire/skills' ] && [ -d '$p/.inspire/templates' ]"
check "the surviving skill of the rename is the new one" \
   "[ -f '$p/.claude/skills/inspire-lesson/SKILL.md' ]"
eq "lock reports the target after the longest chain" \
   "$(jq -r .inspire_version "$p/.inspire.lock")" "$target"

# §6: the report is persisted, so an upgrade stays auditable after the session.
check "the report was saved to .inspire/last-upgrade.log" \
   "[ -f '$p/.inspire/last-upgrade.log' ]"
check "the saved report is the report, not a stub" \
   "grep -q 'INSPIRE upgrade — 0.1.0' '$p/.inspire/last-upgrade.log' && \
    grep -q 'decision(s) needed' '$p/.inspire/last-upgrade.log'"
check "the report tells the operator where it was saved" \
   "printf '%s' \"\$e2e1_err\" | grep -q '.inspire/last-upgrade.log'"
# Outside every dest_map root, or classify's pass 3 would report our own log back
# to the operator as project-authored on the next run — forever.
inlog_n="$(classify "$PLUGIN_ROOT/manifests/0.4.0.json" "$p" "$base" "$MAP_03" "$MAP_03" \
           | grep -c 'last-upgrade.log')"
eq "the log is never classified as project-authored" "$inlog_n" "0"
# One file, overwritten — not a growing log directory.
e2e1_lines="$(wc -l < "$p/.inspire/last-upgrade.log" | tr -d ' ')"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
check "the log is overwritten, never appended to" \
   "[ \"\$(wc -l < '$p/.inspire/last-upgrade.log' | tr -d ' ')\" -lt '$e2e1_lines' ]"
eq "no second log artifact appeared" \
   "$(find "$p/.inspire" -maxdepth 1 -name '*.log' | wc -l | tr -d ' ')" "1"
fixture_cleanup "$w"

# The prune is rmdir, so ONE file of the operator's keeps the whole container —
# and the drain still happens around it. Nothing of theirs may be lost to a
# cleanup whose entire justification is that it cannot lose anything.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.1.0 "$w" "$REPO")"
printf 'MY VALIDATOR\n' > "$p/.claude/bin/my-check.sh"
printf 'MY HOOK\n'      > "$p/.claude/hooks/my-hook.sh"
printf 'MY NOTE\n'      > "$p/.claude/skills/inspire-learn/references/my-note.md"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "0.1.0 → current exits 0 with operator files in the way" "$?" "0"
eq "the operator's validator is untouched" \
   "$(cat "$p/.claude/bin/my-check.sh" 2>/dev/null)" "MY VALIDATOR"
eq "the operator's hook is untouched" \
   "$(cat "$p/.claude/hooks/my-hook.sh" 2>/dev/null)" "MY HOOK"
eq "the operator's note inside the renamed skill is untouched" \
   "$(cat "$p/.claude/skills/inspire-learn/references/my-note.md" 2>/dev/null)" "MY NOTE"
# ...and the containers were genuinely drained, so the prune was reached and
# REFUSED rather than never attempted: only their file is left.
eq "the blocked .claude/bin holds nothing but their file" \
   "$(ls -A "$p/.claude/bin" | tr '\n' ' ')" "my-check.sh "
eq "the blocked .claude/hooks holds nothing but their file" \
   "$(ls -A "$p/.claude/hooks" | tr '\n' ' ')" "my-hook.sh "
eq "all 14 validators + the trust tool still landed" \
   "$(find "$p/.inspire/bin" -maxdepth 1 -type f | wc -l | tr -d ' ')" "15"
fixture_cleanup "$w"

# --mode plan on the longest chain must still write NOTHING — directories
# included, which a file-only fingerprint cannot see now that act mode prunes.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.1.0 "$w" "$REPO")"
plan01_f="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
plan01_d="$(find "$p" -type d | LC_ALL=C sort | shasum -a 256)"
bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "plan on a 0.1.0 tree exits 0" "$?" "0"
eq "plan wrote no file" "$plan01_f" \
   "$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "plan removed no directory either" "$plan01_d" \
   "$(find "$p" -type d | LC_ALL=C sort | shasum -a 256)"
check "plan wrote no upgrade log" "[ ! -e '$p/.inspire/last-upgrade.log' ]"
fixture_cleanup "$w"

# --take-base overrides a conflict.
#
# A 0.2.1 fixture again, and a SKILL: base/ is byte-identical between 0.3.0 and
# 0.3.1, so a 0.3.0 project has no stale file to build a conflict from. Skills
# also live at .claude/skills/ in both layouts, so the path the flag names is the
# same before and after the hops — which is what --take-base takes.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
v="$(mktemp)"
classify "$PLUGIN_ROOT/manifests/0.2.1.json" "$p" "$base" "$MAP_PRE" "$MAP_03" > "$v"
stale="$(awk -F'\t' '$1=="replace" && $2 ~ /^\.claude\/skills\//{print $2; exit}' "$v")"
check "found a stale skill to conflict on" "[ -n '$stale' ]"
printf '\nMY EDIT\n' >> "$p/$stale"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" \
     --take-base "$stale" >/dev/null 2>&1
src_of="skills/${stale#.claude/skills/}"
eq "--take-base installed ours" \
   "$(shasum -a 256 "$p/$stale" | awk '{print $1}')" \
   "$(shasum -a 256 "$base/$src_of" | awk '{print $1}')"

# And the default the other way: an unresolved conflict keeps theirs.
w2="$(mktemp -d)"; p2="$(fixture_from_tag v0.2.1 "$w2" "$REPO")"
printf '\nMY EDIT\n' >> "$p2/$stale"
mine2="$(shasum -a 256 "$p2/$stale" | awk '{print $1}')"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p2" >/dev/null 2>&1
eq "an unresolved conflict defaults to keeping theirs" \
   "$(shasum -a 256 "$p2/$stale" | awk '{print $1}')" "$mine2"
fixture_cleanup "$w2"

# --take-mine is the explicit spelling of that default, and --skip is its
# deprecated alias. Both must resolve the same ask row to `keep`.
w3="$(mktemp -d)"; p3="$(fixture_from_tag v0.2.1 "$w3" "$REPO")"
printf '\nMY EDIT\n' >> "$p3/$stale"
mine3="$(shasum -a 256 "$p3/$stale" | awk '{print $1}')"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p3" \
     --take-mine "$stale" >/dev/null 2>&1
eq "--take-mine keeps theirs" \
   "$(shasum -a 256 "$p3/$stale" | awk '{print $1}')" "$mine3"
fixture_cleanup "$w3"

w4="$(mktemp -d)"; p4="$(fixture_from_tag v0.2.1 "$w4" "$REPO")"
printf '\nMY EDIT\n' >> "$p4/$stale"
mine4="$(shasum -a 256 "$p4/$stale" | awk '{print $1}')"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p4" \
     --skip "$stale" >/dev/null 2>&1
eq "--skip still keeps theirs (deprecated alias)" \
   "$(shasum -a 256 "$p4/$stale" | awk '{print $1}')" "$mine4"
fixture_cleanup "$w4"
rm -f "$v"; fixture_cleanup "$w"

# ---- the half-migrated tree ---------------------------------------------
# THE gap Task 12 left open. A project that ran migration step 1 only
# (`git mv .inspire_kb inspire_kb`) and none of steps 2-6 is not caught by
# require_migrated_layout — inspire_kb/ exists, so that guard stands down —
# yet .claude/skills/ is the SAME destination in both layouts, so the old
# copy path overwrote a locally-edited shipped skill with no drift step and
# no gate. verify_layout is what closes it: the pre-0.3 signature requires
# .inspire_kb/ present and inspire_kb/ absent, and this tree is neither.
# Refusal before anything is written is the only safe answer — the two
# locations cannot be told apart, and guessing risks the live one.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
( cd "$p" && mv .inspire_kb inspire_kb )
printf '\nMY EDIT\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
half_hash="$(shasum -a 256 "$p/.claude/skills/inspire-domain/SKILL.md" | awk '{print $1}')"
half_err="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1 >/dev/null)"
eq "half-migrated tree: update refuses (rc)" "$?" "1"
check "half-migrated tree: the refusal names both KB locations" \
  "printf '%s' \"\$half_err\" | grep -q 'inspire_kb'"
eq "half-migrated tree: the edited skill is untouched" \
   "$(shasum -a 256 "$p/.claude/skills/inspire-domain/SKILL.md" | awk '{print $1}')" "$half_hash"
check "half-migrated tree: nothing was moved" \
  "[ -d '$p/.claude/bin' ] && [ ! -d '$p/.claude/inspire/hooks' ]"
check "half-migrated tree: the 0.2 hook registrations are left as they were" \
  "[ \"\$(jq '[.. | objects | select(has(\"command\")) | select(.command|contains(\".claude/hooks/\"))] | length' '$p/.claude/settings.json')\" = 3 ]"
check "half-migrated tree: no lock was rewritten" \
  "[ \"\$(jq -r .inspire_version '$p/.inspire.lock')\" = '0.2.1' ]"
fixture_cleanup "$w"

# ---- the 0.7.0 hop: derive-then-diff index retirement --------------------
# ALL of these run against a version-patched FAKE plugin root, and must, until
# the release is cut: with plugin.json at 0.6.0 the real root can never source
# hops/0.7.0.sh — run_chain skips versions above the target (chain.sh:41-42),
# and the no-manifest fallback (chain.sh:60-63) looks only for hops/<target>.sh.
# Patching .version to 0.7.0 in a COPY makes that fallback fire, because the
# copied manifests/ has no 0.7.0.json. Two pinned consequences: template_sha in
# these updates is honestly "unknown" (write_lock finds no manifest for the
# target), so nothing here asserts otherwise; and nothing here claims anything
# about the real root's hop effects, which do not exist before the bump.
fake7="$(mktemp -d)"
cp -R "$PLUGIN_ROOT/." "$fake7/plugin"
jq '.version="0.7.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  > "$fake7/plugin/.claude-plugin/plugin.json"
FP7="$fake7/plugin"
hop7="$PLUGIN_ROOT/scripts/hops/0.7.0.sh"
seeds7="$HERE/fixtures/retired-seeds"

# The blob fixtures pin the hop's constants: the seeds left base/kb in this
# release, so these are the only in-tree copies of the shipped bytes. Each
# constant is read out of the hop file itself — the left side is always a real
# hash, so a renamed or missing constant fails loudly, never vacuously.
eq "modules seed blob matches the hop's pinned constant" \
   "$(sha256_of "$seeds7/02_modules__index.md")" \
   "$(awk -F"'" '/^_h7_sha_modules=/{print $2; exit}' "$hop7")"
eq "patterns seed blob matches the hop's pinned constant" \
   "$(sha256_of "$seeds7/05_screens-patterns__index.md")" \
   "$(awk -F"'" '/^_h7_sha_patterns=/{print $2; exit}' "$hop7")"
eq "components seed blob matches the hop's pinned constant" \
   "$(sha256_of "$seeds7/05_screens-components__index.md")" \
   "$(awk -F"'" '/^_h7_sha_components=/{print $2; exit}' "$hop7")"
# The fourth constant — the seed's NON-ROW remainder, the second gate of the
# derive-equal verdict — pinned the same way, via the same extraction the hop
# itself uses (the exact complement of its row filter).
eq "the modules seed's non-row remainder matches the hop's prose constant" \
   "$(awk '!/^[ \t]*\|/' "$seeds7/02_modules__index.md" | shasum -a 256 | awk '{print $1}')" \
   "$(awk -F"'" '/^_h7_sha_modules_prose=/{print $2; exit}' "$hop7")"
check "the five retired seeds are gone from base/kb (nothing to resurrect)" \
   "[ ! -e '$PLUGIN_ROOT/base/kb/02_modules/_index.md' ] && \
    [ ! -e '$PLUGIN_ROOT/base/kb/05_screens/patterns/_index.md' ] && \
    [ ! -e '$PLUGIN_ROOT/base/kb/05_screens/components/_index.md' ] && \
    [ ! -e '$PLUGIN_ROOT/base/kb/02_modules/_template.md' ] && \
    [ ! -e '$PLUGIN_ROOT/base/kb/06_spikes/_template.md' ]"

# ---- unit: the derive/normalize layer, driven directly --------------------
# Sourcing the hop against an empty project performs no operation (neither KB
# root exists, so every per-file driver skips) and leaves the _h7_* helpers
# defined for direct calls — the same direct-drive precedent as the
# hop_ops_init/run_chain section above. The doctrine hop_report is the one
# journal row a no-op source produces.
u7="$(mktemp -d)"; mkdir -p "$u7/proj"
unset HOP_JOURNAL
hop_ops_init "$u7/proj" /dev/null 1
. "$PLUGIN_ROOT/scripts/hops/0.7.0.sh"
eq "sourcing against an empty project journals nothing but the doctrine note" \
   "$(awk -F'\t' '$1!="report"' "$HOP_JOURNAL" | wc -l | tr -d ' ')" "0"

eq "norm: backticks and whitespace runs are presentation" \
   "$(printf '|  Auth  |  `AUTH`  |  [[auth]]  |\n' | _h7_norm_rows)" \
   "| Auth | AUTH | [[auth]] |"
eq "norm: wikilink display text is presentation" \
   "$(printf '| Auth | AUTH | [[auth|Auth]] |\n' | _h7_norm_rows)" \
   "| Auth | AUTH | [[auth]] |"
eq "norm: CR line endings are presentation" \
   "$(printf '| Auth | AUTH | [[auth]] |\r\n' | _h7_norm_rows)" \
   "| Auth | AUTH | [[auth]] |"
eq "norm: duplicate rows survive to diverge (no sort -u)" \
   "$(printf '| A | A | [[a]] |\n| A | A | [[a]] |\n' | _h7_norm_rows | wc -l | tr -d ' ')" "2"

# The separator filter is shape-based: |---| rows (alignment colons included)
# drop; the canonical header drops; a row of EMPTY cells and a reshaped header
# both SURVIVE into the row-set, where they diverge and ask — the filter must
# never eat content, because everything it eats is invisible to the compare.
cat > "$u7/reg.md" <<'EOF'
# Modules — registry

| Module | Prefix | Hub |
|--------|--------|-----|
| Auth | `AUTH` | [[auth]] |
| :--- | ---: | - |
|  |  |  |
| Hub | Module | Prefix |
EOF
eq "disk rows: separators and header drop; empty-cell and reshaped rows survive" \
   "$(_h7_disk_rows "$u7/reg.md")" \
"| Auth | AUTH | [[auth]] |
| Hub | Module | Prefix |
| | | |"

mkdir -p "$u7/hubs"
printf -- '---\nkind: module-hub\nprefix: AUTH              # trailing comment must strip\n---\n\n# Auth\n' > "$u7/hubs/auth.md"
printf -- '---\nprefix: `BILL`\n---\n\n# Billing\n' > "$u7/hubs/billing.md"
printf 'never a hub\n' > "$u7/hubs/_template.md"
printf 'never a hub\n' > "$u7/hubs/README.md"
eq "derive: H1 + prefix per hub; comment stripped; backticks normalized; _* and README skipped" \
   "$(_h7_derive_registry "$u7/hubs")" \
"| Auth | AUTH | [[auth]] |
| Billing | BILL | [[billing]] |"

mkdir -p "$u7/noh1"
printf -- '---\nprefix: X\n---\nno heading here\n' > "$u7/noh1/x.md"
_h7_derive_registry "$u7/noh1" >/dev/null 2>&1
eq "derive: a hub missing its H1 is not provable (rc 1)" "$?" "1"

mkdir -p "$u7/nopfx"
printf -- '---\nkind: module-hub\n---\n\n# X\n' > "$u7/nopfx/x.md"
_h7_derive_registry "$u7/nopfx" >/dev/null 2>&1
eq "derive: a hub missing its prefix is not provable (rc 1)" "$?" "1"

mkdir -p "$u7/nohubs"
_h7_derive_registry "$u7/nohubs" >/dev/null 2>&1
eq "derive: zero hubs prove nothing (rc 1)" "$?" "1"
rm -rf "$u7"

# ---- the derive-equal branch, end to end -----------------------------------
# The branch a pristine fixture can never exercise: two real hubs, a registry
# whose rows are exactly their derivation (in reverse order, one row
# backticked, one carrying display text — so the equality is normalized and
# order-insensitive, not byte-lucky), and the seed's own prose around the
# table. Both gates hold → all three indexes retire, no questions.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
printf -- '---\nkind: module-hub\nprefix: AUTH              # the module'"'"'s feature / use-case ID prefix\n---\n\n# Auth\n' \
  > "$p/inspire_kb/02_modules/auth.md"
printf -- '---\nkind: module-hub\nprefix: BILL\n---\n\n# Billing\n' \
  > "$p/inspire_kb/02_modules/billing.md"
h7_reg="$p/inspire_kb/02_modules/_index.md"
grep -v '_e\.g\._' "$h7_reg" > "$h7_reg.tmp" && mv "$h7_reg.tmp" "$h7_reg"
printf '| Billing | `BILL` | [[billing]] |\n| Auth | AUTH | [[auth|Auth]] |\n' >> "$h7_reg"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
eq "derive-equal: hub-backed rows behind pristine prose retire silently" \
   "$(printf '%s' "$h7_plan" | jq -cr '[.verdicts.delete, (.ask|length)]')" "[3,0]"

# BLOCKER-1 regression: authored prose around a PERFECTLY-synced table is
# content the row compare cannot see — the non-row gate must route it to ask.
printf '\nTeam note: check with Ops before renaming modules.\n' >> "$h7_reg"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
eq "derive-equal is gated on pristine prose: an added note asks instead" \
   "$(printf '%s' "$h7_plan" | jq -cr '[.verdicts.delete, .ask]')" \
   '[2,["inspire_kb/02_modules/_index.md"]]'

# BLOCKER-2 regression: zero hubs and a deleted example row must not compare
# "equal to nothing" and retire — nothing to derive from is not a proof.
rm -f "$p/inspire_kb/02_modules/auth.md" "$p/inspire_kb/02_modules/billing.md"
grep -v '_e\.g\._' "$seeds7/02_modules__index.md" > "$h7_reg"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
eq "an empty derivation proves nothing: table-less registry asks" \
   "$(printf '%s' "$h7_plan" | jq -cr '[.verdicts.delete, .ask]')" \
   '[2,["inspire_kb/02_modules/_index.md"]]'
fixture_cleanup "$w"

# Pristine seeds: plan predicts 3 silent deletes and no questions, writes
# nothing (record/act parity, files AND directories), and the subsequent real
# update lands exactly the predicted split — the three files disappear and
# NOTHING else does. The premise is asserted first: on drifted fixture seeds
# every retire-verdict below would pass for the wrong reason.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
h7_pristine=0
for h7_pair in \
  "inspire_kb/02_modules/_index.md:02_modules__index.md" \
  "inspire_kb/05_screens/patterns/_index.md:05_screens-patterns__index.md" \
  "inspire_kb/05_screens/components/_index.md:05_screens-components__index.md"; do
  [ "$(sha256_of "$p/${h7_pair%%:*}")" = "$(sha256_of "$seeds7/${h7_pair#*:}")" ] \
    && h7_pristine=$((h7_pristine+1))
done
eq "premise: the v0.6.0 fixture carries all three seeds pristine" "$h7_pristine" "3"

h7_before_f="$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
h7_before_d="$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"
h7_list_before="$(cd "$p" && find . -type f | LC_ALL=C sort)"
h7_plan_log="$(mktemp)"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>"$h7_plan_log")"
h7_rc=$?
eq "fake-root plan exits 0" "$h7_rc" "0"
check "plan's chain reaches 0.7.0 via the no-manifest fallback" \
  "[ \"\$(printf '%s' \"\$h7_plan\" | jq -r '.chain|index(\"0.7.0\")')\" != null ]"
eq "plan predicts exactly the 3 retirements (delete count)" \
   "$(printf '%s' "$h7_plan" | jq -r '.verdicts.delete')" "3"
eq "plan predicts no questions (merged ask count)" \
   "$(printf '%s' "$h7_plan" | jq -r '.verdicts.ask')" "0"
eq "plan predicts no questions (ask[])" \
   "$(printf '%s' "$h7_plan" | jq -r '.ask|length')" "0"
check "plan names all three retirements in the post-hop space" \
  "grep -q 'delete   inspire_kb/02_modules/_index.md' '$h7_plan_log' && \
   grep -q 'delete   inspire_kb/05_screens/patterns/_index.md' '$h7_plan_log' && \
   grep -q 'delete   inspire_kb/05_screens/components/_index.md' '$h7_plan_log'"
eq "plan wrote no file" "$h7_before_f" \
   "$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "plan removed no directory" "$h7_before_d" \
   "$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"

h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
h7_rc=$?
eq "fake-root update exits 0" "$h7_rc" "0"
check "the three retired indexes are gone" \
  "[ ! -e '$p/inspire_kb/02_modules/_index.md' ] && \
   [ ! -e '$p/inspire_kb/05_screens/patterns/_index.md' ] && \
   [ ! -e '$p/inspire_kb/05_screens/components/_index.md' ]"
# Record/act parity on the whole tree: the set of files that DISAPPEARED is
# exactly the set the plan predicted — additions (lock, log, seeds) are the
# update's normal business and are not losses.
h7_lost="$(comm -23 <(printf '%s\n' "$h7_list_before") <(cd "$p" && find . -type f | LC_ALL=C sort))"
eq "only the three predicted files disappeared" "$h7_lost" \
"./inspire_kb/02_modules/_index.md
./inspire_kb/05_screens/components/_index.md
./inspire_kb/05_screens/patterns/_index.md"
eq "update leaves no question open" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|length')" "0"
eq "the lock stamps 0.7.0" "$(jq -r .inspire_version "$p/.inspire.lock")" "0.7.0"
rm -f "$h7_plan_log"
fixture_cleanup "$w"

# A diverged registry and a project-created ADR index are QUESTIONS, in the
# plan and in an unresolved update alike — and the unresolved default keeps
# both files while the two provably-pristine TOCs still retire around them.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
printf '| Auth | `AUTH` | [[auth]] |\n' >> "$p/inspire_kb/02_modules/_index.md"
printf '# ADR index\n' > "$p/inspire_kb/01_adr/_index.md"
h7_reg_sha="$(sha256_of "$p/inspire_kb/02_modules/_index.md")"
h7_adr_sha="$(sha256_of "$p/inspire_kb/01_adr/_index.md")"
h7_plan_log="$(mktemp)"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>"$h7_plan_log")"
eq "diverged plan asks about both files (ask[])" \
   "$(printf '%s' "$h7_plan" | jq -r '.ask|sort|join(" ")')" \
   "inspire_kb/01_adr/_index.md inspire_kb/02_modules/_index.md"
eq "diverged plan's merged ask count agrees" \
   "$(printf '%s' "$h7_plan" | jq -r '.verdicts.ask')" "2"
eq "the two pristine TOCs still retire around the questions" \
   "$(printf '%s' "$h7_plan" | jq -r '.verdicts.delete')" "2"
check "the footer counts the same two decisions" \
  "grep -q '2 decision(s) needed' '$h7_plan_log'"
h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
check "unresolved update keeps the diverged registry and the ADR index" \
  "[ -f '$p/inspire_kb/02_modules/_index.md' ] && [ -f '$p/inspire_kb/01_adr/_index.md' ]"
# Kept means BYTE-untouched, not merely present — "keep" that rewrites is the
# failure the whole default exists to rule out.
eq "the kept registry is byte-identical" \
   "$(sha256_of "$p/inspire_kb/02_modules/_index.md")" "$h7_reg_sha"
eq "the kept ADR index is byte-identical" \
   "$(sha256_of "$p/inspire_kb/01_adr/_index.md")" "$h7_adr_sha"
eq "both questions are still open in the update's ask[]" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|sort|join(" ")')" \
   "inspire_kb/01_adr/_index.md inspire_kb/02_modules/_index.md"
check "the persisted report carries the ASK rows" \
  "grep -q 'ASK      inspire_kb/02_modules/_index.md' '$p/.inspire/last-upgrade.log' && \
   grep -q 'ASK      inspire_kb/01_adr/_index.md' '$p/.inspire/last-upgrade.log'"
rm -f "$h7_plan_log"
fixture_cleanup "$w"

# --take-base retires the diverged file on the operator's word (journalled as
# the delete it is), and a misspelled path warns on BOTH channels — warnings[]
# and stderr — because silent-keep is exactly what a typo would otherwise look
# like.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
printf '| Auth | `AUTH` | [[auth]] |\n' >> "$p/inspire_kb/02_modules/_index.md"
h7_up_log="$(mktemp)"
h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" \
         --take-base inspire_kb/02_modules/_index.md \
         --take-base inspire_kb/02_moduelz/_index.md 2>"$h7_up_log")"
h7_rc=$?
eq "update with --take-base exits 0" "$h7_rc" "0"
check "--take-base retired the diverged registry" \
  "[ ! -e '$p/inspire_kb/02_modules/_index.md' ]"
check "the resolution is journalled as the delete it became" \
  "grep -q 'delete   inspire_kb/02_modules/_index.md' '$p/.inspire/last-upgrade.log'"
eq "no question stays open once resolved" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|length')" "0"
eq "exactly the misspelled path warns in warnings[]" \
   "$(printf '%s' "$h7_up" | jq -r '[.warnings[]|select(contains("matched nothing"))]|length')" "1"
check "the warning names the misspelled path, not the consumed one" \
  "printf '%s' \"\$h7_up\" | jq -r '.warnings[]' | grep 'matched nothing' | grep -q '02_moduelz'"
check "the same warning reached stderr" \
  "grep -q '02_moduelz.*matched nothing' '$h7_up_log'"
rm -f "$h7_up_log"
fixture_cleanup "$w"

# --take-mine keeps — and it must be journalled as a keep even when the
# verdict would have retired the file silently (the pristine patterns TOC
# here): a consumed resolution must appear in the journal under SOME verb, or
# the unmatched-resolution warning would fire about an answer that was
# honoured (the contract pinned in _warn_unmatched_resolutions).
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
printf '| Auth | `AUTH` | [[auth]] |\n' >> "$p/inspire_kb/02_modules/_index.md"
h7_reg_sha="$(sha256_of "$p/inspire_kb/02_modules/_index.md")"
h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" \
         --take-mine inspire_kb/02_modules/_index.md \
         --take-mine inspire_kb/05_screens/patterns/_index.md 2>/dev/null)"
check "--take-mine kept the diverged registry" \
  "[ -f '$p/inspire_kb/02_modules/_index.md' ]"
eq "--take-mine kept it byte-identical" \
   "$(sha256_of "$p/inspire_kb/02_modules/_index.md")" "$h7_reg_sha"
check "--take-mine kept the pristine TOC the verdict would have retired" \
  "[ -f '$p/inspire_kb/05_screens/patterns/_index.md' ]"
check "the unresolved pristine TOC still retired around them" \
  "[ ! -e '$p/inspire_kb/05_screens/components/_index.md' ]"
check "both keeps are journalled as the operator's instruction" \
  "grep -q 'keep     inspire_kb/02_modules/_index.md.*your instruction' '$p/.inspire/last-upgrade.log' && \
   grep -q 'keep     inspire_kb/05_screens/patterns/_index.md.*your instruction' '$p/.inspire/last-upgrade.log'"
eq "a consumed resolution is not an open question" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|length')" "0"
eq "a consumed resolution draws no unmatched warning" \
   "$(printf '%s' "$h7_up" | jq -r '[.warnings[]|select(contains("matched nothing"))]|length')" "0"
fixture_cleanup "$w"

# Pre-0.3 parity — the case the whole root-resolution design exists for. In
# record mode the 0.3.0 hop has journalled its moves but NOT performed them
# (hop_mv's record branch returns before the mv), so when this hop is sourced
# in the same ascending pass the KB is still at .inspire_kb/ — yet every path
# it journals must already be in the POST-hop space, or the plan's ask[] hands
# the operator a path no --take-* flag could ever match. The act run then has
# to land exactly the split the record run predicted.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.1.0 "$w" "$REPO")"
h7_pristine=0
for h7_pair in \
  ".inspire_kb/02_modules/_index.md:02_modules__index.md" \
  ".inspire_kb/05_screens/patterns/_index.md:05_screens-patterns__index.md" \
  ".inspire_kb/05_screens/components/_index.md:05_screens-components__index.md"; do
  [ "$(sha256_of "$p/${h7_pair%%:*}")" = "$(sha256_of "$seeds7/${h7_pair#*:}")" ] \
    && h7_pristine=$((h7_pristine+1))
done
eq "premise: the v0.1.0 fixture carries all three seeds pristine at .inspire_kb" \
   "$h7_pristine" "3"
h7_before_f="$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
h7_before_d="$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"
h7_kb_before="$(cd "$p/.inspire_kb" && find . -type f | LC_ALL=C sort)"
h7_plan_log="$(mktemp)"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>"$h7_plan_log")"
h7_rc=$?
eq "pre-0.3 fake-root plan exits 0" "$h7_rc" "0"
eq "the chain runs 0.3.0 then 0.7.0 in one pass" \
   "$(printf '%s' "$h7_plan" | jq -cr '.chain')" '["0.3.0","0.7.0"]'
eq "pre-0.3 plan predicts no questions" \
   "$(printf '%s' "$h7_plan" | jq -r '.ask|length')" "0"
check "the predicted retirements are in the POST-hop path space" \
  "grep -q 'delete   inspire_kb/02_modules/_index.md' '$h7_plan_log' && \
   grep -q 'delete   inspire_kb/05_screens/patterns/_index.md' '$h7_plan_log' && \
   grep -q 'delete   inspire_kb/05_screens/components/_index.md' '$h7_plan_log'"
check "no retirement leaks the pre-hop path space" \
  "! grep -q 'delete   \.inspire_kb/' '$h7_plan_log'"
eq "pre-0.3 plan wrote no file" "$h7_before_f" \
   "$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "pre-0.3 plan removed no directory" "$h7_before_d" \
   "$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"

h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
h7_rc=$?
eq "pre-0.3 fake-root update exits 0" "$h7_rc" "0"
check "the KB moved and the old root is gone" \
  "[ -d '$p/inspire_kb' ] && [ ! -e '$p/.inspire_kb' ]"
# Same subtree, same comparison as the 0.6.0 case: within the KB, the act run
# lost exactly what the record run predicted — the rename is factored out by
# comparing the two roots' relative trees, and seed additions are not losses.
h7_lost="$(comm -23 <(printf '%s\n' "$h7_kb_before") <(cd "$p/inspire_kb" && find . -type f | LC_ALL=C sort))"
eq "the KB lost exactly the three predicted files, nothing else" "$h7_lost" \
"./02_modules/_index.md
./05_screens/components/_index.md
./05_screens/patterns/_index.md"
eq "pre-0.3 update leaves no question open" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|length')" "0"
eq "the lock stamps 0.7.0 after the longest chain" \
   "$(jq -r .inspire_version "$p/.inspire.lock")" "0.7.0"
rm -f "$h7_plan_log"
fixture_cleanup "$w"
rm -rf "$fake7"

echo ""; echo "Passed: $pass · Failed: $fail · Skipped: $skip"
[ "$fail" -eq 0 ]
