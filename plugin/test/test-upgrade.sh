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

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
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
# Record mode must PREDICT the directory removal, not just the file deletions.
check "record mode predicts the directory removal" \
  "grep -q \$'^delete\t.claude/bin/test/\tdirectory emptied and removed$' '$HOP_JOURNAL'"
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
  echo "SKIP permission-failure assertions — writable despite chmod 555 (running as root?)"
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

echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
