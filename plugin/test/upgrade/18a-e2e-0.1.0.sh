#!/usr/bin/env bash
# End to end: 0.1.0 -> current, the longest chain there is.
# Cut from upgrade/18-e2e-0.1.0.sh:20-157 (test-upgrade.sh:1359-1496).
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
MAP_PRE="$(layout_map "$PLUGIN_ROOT" pre-0.3)"
MZ="$PLUGIN_ROOT/scripts/materialize.sh"
target="$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")"

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
#
# The expected count is READ FROM THE PLUGIN, not written down here. A literal
# went stale the moment base/bin gained an entry (it said 16 while 22 shipped),
# which is a failure that says nothing about the pruning under test. Deriving it
# from base/bin is not the vacuous form either — this asserts the SOURCE side
# against the DESTINATION side, and the floor below keeps an emptied base/bin
# from making it pass for free.
BIN_SHIPPED="$(find "$PLUGIN_ROOT/base/bin" -maxdepth 1 -type f | wc -l | tr -d ' ')"
check "premise: the plugin ships a full validator set to land" "[ '$BIN_SHIPPED' -ge 16 ]"
eq "every base/bin entry landed at .inspire/bin" \
   "$(find "$p/.inspire/bin" -maxdepth 1 -type f | wc -l | tr -d ' ')" "$BIN_SHIPPED"
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
# One file, overwritten — not a growing log directory. Dual-state, for exactly the
# reason spelled out at the 0.2.1 block's second run above: a post-update tree only
# re-detects while plugin/base/ still matches the newest SHIPPED manifest at or
# above MANIFEST_FLOOR_PCT, and mid-release — before release step T11-3 generates
# the manifest for the version being prepared — it does not, so detection refuses
# rather than guess a baseline. Both behaviours are pinned:
#   RELEASED    — the run converges and rewrites the log SHORTER (a converged pass
#                 has almost nothing left to report).
#   MID-RELEASE — detection refuses before a byte is written, so the log must come
#                 out BYTE-identical. "Not longer" would be satisfied by a partial
#                 rewrite, which is precisely what an aborted run must never leave
#                 behind, so the refusal branch compares hashes and not line counts.
# The log is known non-empty here: "the saved report is the report, not a stub"
# above asserts its content, so neither branch is comparing against nothing.
e2e1_lines="$(wc -l < "$p/.inspire/last-upgrade.log" | tr -d ' ')"
e2e1_log_sha="$(shasum -a 256 "$p/.inspire/last-upgrade.log" | awk '{print $1}')"
e2e1_lock_sha="$(shasum -a 256 "$p/.inspire.lock" | awk '{print $1}')"
detect_version "$PLUGIN_ROOT" "$p" >/dev/null 2>&1; e2e1_detectable=$?
e2e1_rerun_err="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>&1 >/dev/null)"
e2e1_rerun_rc=$?
if [ "$e2e1_detectable" -eq 0 ]; then
  eq "released state: the second run converges (rc)" "$e2e1_rerun_rc" "0"
  check "the log is overwritten, never appended to" \
     "[ \"\$(wc -l < '$p/.inspire/last-upgrade.log' | tr -d ' ')\" -lt '$e2e1_lines' ]"
else
  eq "mid-release: the 0.1.0 tree's second run refuses (rc)" "$e2e1_rerun_rc" "1"
  eq "mid-release: the refusal is detection's own" \
     "$(printf '%s\n' "$e2e1_rerun_err" | grep -c "cannot identify this project's INSPIRE version")" "1"
  eq "mid-release: a refused run leaves the log byte-identical" \
     "$(shasum -a 256 "$p/.inspire/last-upgrade.log" | awk '{print $1}')" "$e2e1_log_sha"
  eq "mid-release: a refused run restamps no lock" \
     "$(shasum -a 256 "$p/.inspire.lock" | awk '{print $1}')" "$e2e1_lock_sha"
fi
# Unconditional: one log file either way — a refusal must not fork a second one any
# more than a converging run may.
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
eq "every base/bin entry still landed" \
   "$(find "$p/.inspire/bin" -maxdepth 1 -type f | wc -l | tr -d ' ')" "$BIN_SHIPPED"
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

summary
