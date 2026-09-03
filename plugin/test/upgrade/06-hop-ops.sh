#!/usr/bin/env bash
# The five hop operations, in act and record mode.
# Moved from test-upgrade.sh:192-459.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$HERE/lib/upgrade-helpers.sh"

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

summary
