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
before="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
hop_ops_init "$p" "$mf" 1
hop_mv .claude/bin/review.sh .inspire/bin/review.sh
hop_rm_owned .claude/bin/test
hop_rm .inspire/install.sh
after="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "record mode wrote nothing" "$before" "$after"
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

echo ""; echo "Passed: $pass · Failed: $fail · Skipped: $skip"
[ "$fail" -eq 0 ]
