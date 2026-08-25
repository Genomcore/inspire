#!/usr/bin/env bash
# plugin/base/bin/test/test-harvest.sh — behavioural tests for `emanate-harvest.sh`
#
# emanate-harvest.sh is a tool, not a review rule (D8; trust.sh's precedent):
# it emits no findings and there is no inspire_kb/ tree to scan, so the golden
# fixture runner (run-tests.sh, which discovers fixtures/<rule>/<scenario>/ and
# exports SDD_SPEC_ROOT/SDD_KB_ROOT for a rule script to scan) cannot exercise
# it — a harvest fixture's whole point is git state (refs, reflog, tree
# contents) that runner has no vocabulary for. This script is wired into
# run-tests.sh explicitly, the same way test-trust.sh is.
#
# Every test builds its own scratch git repo + worktree(s) under one mktemp -d
# root (never in-tree, never a fixed path) and asserts real GIT STATE — tree
# contents at the integration ref, whether the ref moved, reflog length — not
# just exit codes and stdout/stderr text, per this repo's vacuous-assertion
# rule. The stub-guard section at the end proves that: it re-runs two of the
# assertions above against deliberately-broken copies of the script and checks
# that they fail, so a reader can trust that they were checking something.
#
# Usage: bash plugin/base/bin/test/test-harvest.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
HARVEST="$HERE/../emanate-harvest.sh"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
ne(){ if [ "$2" != "$3" ]; then ok "$1"; else bad "$1 (both are '$2')"; fi; }
has(){ if printf '%s\n' "$3" | grep -Fq -- "$2"; then ok "$1"; else bad "$1 (no match for '$2')"; fi; }

if [ ! -x "$HARVEST" ]; then
  echo "FAIL emanate-harvest.sh is not executable at $HARVEST" >&2
  echo ""; echo "Passed: 0 · Failed: 1"
  exit 1
fi

ROOT="$(mktemp -d -t inspire-harvest-test.XXXXXX)" || exit 1
trap 'rm -rf "$ROOT"' EXIT

# fresh_repo <dir> — a scratch repo, HEAD checked out on "integration", with
# source/{a,other}.txt and tests/a.test.txt each committed once as "orig".
fresh_repo() {
  local r="$1"
  git init -q "$r"
  git -C "$r" config user.email tester@example.com
  git -C "$r" config user.name tester
  mkdir -p "$r/source" "$r/tests"
  printf 'orig\n' > "$r/source/a.txt"
  printf 'orig\n' > "$r/source/other.txt"
  printf 'orig\n' > "$r/tests/a.test.txt"
  git -C "$r" add -A
  git -C "$r" commit -q -m init >/dev/null
  git -C "$r" checkout -q -b integration
}

# new_phase <repo> <wt> <branch> — a worktree cut from the repo's current
# integration tip.
new_phase() {
  git -C "$1" worktree add -q -b "$3" "$2" integration
}

tip_sha() { git -C "$1" rev-parse integration; }
reflog_n() { git -C "$1" reflog show integration 2>/dev/null | wc -l | tr -d ' '; }
# path_exists_at <repo> <ref:path> — 0 if that blob exists, 1 if not.
path_exists_at() { git -C "$1" cat-file -e "$2" >/dev/null 2>&1; }
json_field() { printf '%s' "$1" | jq -r "$2"; }

# ═══════════════════════════════════════════════════════════════════════════
# 1 — clean owned-only harvest
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r1"; WT="$ROOT/wt1"
fresh_repo "$R"
new_phase "$R" "$WT" phase1
printf 'impl\n' > "$WT/source/a.txt"
printf 'brand-new\n' > "$WT/source/b.txt"

OUT="$(cd "$R" && "$HARVEST" "$WT" integration --label clean -- 'source/**')"
rc=$?
eq "clean: exit 0" "$rc" "0"
eq "clean: a.txt landed on integration" "$(git -C "$R" show integration:source/a.txt)" "impl"
eq "clean: new file b.txt landed on integration" "$(git -C "$R" show integration:source/b.txt)" "brand-new"
eq "clean: JSON harvested is exact" "$(json_field "$OUT" '.harvested | sort | join(",")')" "source/a.txt,source/b.txt"
eq "clean: JSON dropped is empty" "$(json_field "$OUT" '.dropped | length')" "0"
eq "clean: JSON commit matches the new integration tip" "$(json_field "$OUT" '.commit')" "$(tip_sha "$R")"

# ═══════════════════════════════════════════════════════════════════════════
# 2 — owned + non-owned mixed: the dropped list is EXACT
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r2"; WT="$ROOT/wt2"
fresh_repo "$R"
new_phase "$R" "$WT" phase2
printf 'impl\n' > "$WT/source/a.txt"
printf 'off-scope\n' > "$WT/tests/a.test.txt"

OUT="$(cd "$R" && "$HARVEST" "$WT" integration --label mixed -- 'source/**')"
eq "mixed: exit 0" "$?" "0"
eq "mixed: harvested is exactly source/a.txt" "$(json_field "$OUT" '.harvested | join(",")')" "source/a.txt"
eq "mixed: dropped is exactly tests/a.test.txt" "$(json_field "$OUT" '.dropped | join(",")')" "tests/a.test.txt"
eq "mixed: dropped file never reached integration" "$(git -C "$R" show integration:tests/a.test.txt)" "orig"

# ═══════════════════════════════════════════════════════════════════════════
# 3 — new / deleted / renamed file, all inside owned
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r3"; WT="$ROOT/wt3"
fresh_repo "$R"
new_phase "$R" "$WT" phase3
printf 'fresh\n' > "$WT/source/new.txt"
rm "$WT/source/other.txt"
mv "$WT/source/a.txt" "$WT/source/renamed.txt"

eq "delrename: exit 0" "$(cd "$R" && "$HARVEST" "$WT" integration --label delrename -- 'source/**' >/dev/null; echo $?)" "0"
eq "delrename: new file present" "$(git -C "$R" show integration:source/new.txt)" "fresh"
if path_exists_at "$R" integration:source/other.txt; then bad "delrename: deleted file still present"; else ok "delrename: deleted file is gone"; fi
if path_exists_at "$R" integration:source/a.txt; then bad "delrename: old rename path still present"; else ok "delrename: old rename path is gone"; fi
eq "delrename: renamed file carries the original content" "$(git -C "$R" show integration:source/renamed.txt)" "orig"

# ═══════════════════════════════════════════════════════════════════════════
# 4 — freeze probe: a TESTER phase edits source → dropped, never harvested
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r4"; WT="$ROOT/wt4"
fresh_repo "$R"
new_phase "$R" "$WT" phase4
printf 'new-test\n' > "$WT/tests/new.test.txt"
printf 'tester-touched-source\n' > "$WT/source/a.txt"

OUT="$(cd "$R" && "$HARVEST" "$WT" integration --label tester -- 'tests/**')"
eq "freeze/tester: exit 0" "$?" "0"
eq "freeze/tester: the test file was harvested" "$(git -C "$R" show integration:tests/new.test.txt)" "new-test"
eq "freeze/tester: source/a.txt is UNCHANGED on integration despite the edit" "$(git -C "$R" show integration:source/a.txt)" "orig"
has "freeze/tester: source/a.txt is in the dropped list" "source/a.txt" "$(json_field "$OUT" '.dropped | join(",")')"

# ═══════════════════════════════════════════════════════════════════════════
# 5 — freeze probe: an IMPLEMENTER phase edits tests/** → dropped via
#     :(exclude), never harvested
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r5"; WT="$ROOT/wt5"
fresh_repo "$R"
new_phase "$R" "$WT" phase5
printf 'impl\n' > "$WT/source/a.txt"
printf 'implementer-touched-tests\n' > "$WT/tests/a.test.txt"

OUT="$(cd "$R" && "$HARVEST" "$WT" integration --label implementer -- 'source/**' ':(exclude)tests/**')"
eq "freeze/implementer: exit 0" "$?" "0"
eq "freeze/implementer: source/a.txt harvested" "$(git -C "$R" show integration:source/a.txt)" "impl"
eq "freeze/implementer: tests/a.test.txt is UNCHANGED on integration despite the edit" "$(git -C "$R" show integration:tests/a.test.txt)" "orig"
has "freeze/implementer: tests/a.test.txt is in the dropped list" "tests/a.test.txt" "$(json_field "$OUT" '.dropped | join(",")')"

# ═══════════════════════════════════════════════════════════════════════════
# 6 — empty owned diff: its own exit code, no commit, ref untouched
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r6"; WT="$ROOT/wt6"
fresh_repo "$R"
new_phase "$R" "$WT" phase6
printf 'irrelevant\n' > "$WT/tests/a.test.txt"
before="$(tip_sha "$R")"

OUT="$(cd "$R" && "$HARVEST" "$WT" integration --label empty -- 'source/**')"
rc=$?
eq "empty: exit 6" "$rc" "6"
eq "empty: integration ref did not move" "$(tip_sha "$R")" "$before"
eq "empty: JSON commit is null" "$(json_field "$OUT" '.commit')" "null"
has "empty: dropped still reports the off-scope edit (the real signal)" "tests/a.test.txt" "$(json_field "$OUT" '.dropped | join(",")')"

# ═══════════════════════════════════════════════════════════════════════════
# 7 — integration ref advanced since cut, DISJOINT paths → applies cleanly
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r7"; WT="$ROOT/wt7"
fresh_repo "$R"
new_phase "$R" "$WT" phase7
printf 'impl\n' > "$WT/source/a.txt"
# integration itself (checked out in $R) advances independently, touching a
# DIFFERENT owned-eligible file.
printf 'advanced-independently\n' > "$R/source/other.txt"
git -C "$R" commit -qam "advance integration, disjoint file"

eq "disjoint: exit 0" "$(cd "$R" && "$HARVEST" "$WT" integration --label disjoint -- 'source/**' >/dev/null; echo $?)" "0"
eq "disjoint: the phase's change landed" "$(git -C "$R" show integration:source/a.txt)" "impl"
eq "disjoint: the tip's own independent advance survived" "$(git -C "$R" show integration:source/other.txt)" "advanced-independently"

# ═══════════════════════════════════════════════════════════════════════════
# 8 — integration ref advanced since cut, OVERLAPPING paths → refuses,
#     every ref left exactly as found
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r8"; WT="$ROOT/wt8"
fresh_repo "$R"
new_phase "$R" "$WT" phase8
printf 'impl\n' > "$WT/source/a.txt"
# integration advances independently, touching the SAME owned file.
printf 'advanced-independently\n' > "$R/source/a.txt"
git -C "$R" commit -qam "advance integration, overlapping file"
before="$(tip_sha "$R")"
before_reflog="$(reflog_n "$R")"

rc=0; ( cd "$R" && "$HARVEST" "$WT" integration --label conflict -- 'source/**' >/dev/null 2>&1 ) || rc=$?
eq "conflict: exit 7" "$rc" "7"
eq "conflict: integration ref unchanged" "$(tip_sha "$R")" "$before"
eq "conflict: reflog did not grow" "$(reflog_n "$R")" "$before_reflog"
eq "conflict: the tip's own content survives untouched" "$(git -C "$R" show integration:source/a.txt)" "advanced-independently"

# ═══════════════════════════════════════════════════════════════════════════
# 9 — refusals: not-a-worktree (absent path; a foreign repo), ref missing,
#     no pathspec
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r9"; WT="$ROOT/wt9"
fresh_repo "$R"
new_phase "$R" "$WT" phase9

rc=0; ( cd "$R" && "$HARVEST" "$ROOT/does-not-exist" integration --label x -- 'source/**' >/dev/null 2>&1 ) || rc=$?
eq "refuse: absent worktree path — exit 3" "$rc" "3"

FOREIGN="$ROOT/foreign-repo"
git init -q "$FOREIGN"
rc=0; ( cd "$R" && "$HARVEST" "$FOREIGN" integration --label x -- 'source/**' >/dev/null 2>&1 ) || rc=$?
eq "refuse: a git dir that is not a worktree of THIS repo — exit 3" "$rc" "3"

rc=0; ( cd "$R" && "$HARVEST" "$WT" no-such-branch --label x -- 'source/**' >/dev/null 2>&1 ) || rc=$?
eq "refuse: missing integration ref — exit 4" "$rc" "4"

rc=0; ( cd "$R" && "$HARVEST" "$WT" integration --label x -- >/dev/null 2>&1 ) || rc=$?
eq "refuse: no pathspec after -- — exit 5" "$rc" "5"

rc=0; ( cd "$R" && "$HARVEST" "$WT" integration --label x >/dev/null 2>&1 ) || rc=$?
eq "refuse: -- omitted entirely — exit 5" "$rc" "5"

# ═══════════════════════════════════════════════════════════════════════════
# 10 — plan mode / --dry-run: same verdict, writes NOTHING (ref + reflog
#      unchanged), no commit
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/r10"; WT="$ROOT/wt10"
fresh_repo "$R"
new_phase "$R" "$WT" phase10
printf 'impl\n' > "$WT/source/a.txt"
before="$(tip_sha "$R")"
before_reflog="$(reflog_n "$R")"

OUT="$(cd "$R" && "$HARVEST" "$WT" integration --label plan --mode plan -- 'source/**')"
eq "plan: exit 0" "$?" "0"
eq "plan: ref unchanged" "$(tip_sha "$R")" "$before"
eq "plan: reflog unchanged" "$(reflog_n "$R")" "$before_reflog"
eq "plan: JSON commit is null" "$(json_field "$OUT" '.commit')" "null"
eq "plan: would-harvest list still reports the real content" "$(json_field "$OUT" '.harvested | join(",")')" "source/a.txt"
eq "plan: source/a.txt on integration is still the original" "$(git -C "$R" show integration:source/a.txt)" "orig"

OUT2="$(cd "$R" && "$HARVEST" "$WT" integration --label dryrun --dry-run -- 'source/**')"
eq "--dry-run: exit 0" "$?" "0"
eq "--dry-run: ref unchanged" "$(tip_sha "$R")" "$before"
eq "--dry-run: reflog unchanged" "$(reflog_n "$R")" "$before_reflog"

# ═══════════════════════════════════════════════════════════════════════════
# 11 — --discard: only after success, only with the flag
# ═══════════════════════════════════════════════════════════════════════════

# 11a. success WITHOUT --discard: worktree and branch survive.
R="$ROOT/r11a"; WT="$ROOT/wt11a"
fresh_repo "$R"
new_phase "$R" "$WT" phase11a
printf 'impl\n' > "$WT/source/a.txt"
( cd "$R" && "$HARVEST" "$WT" integration --label keep -- 'source/**' >/dev/null )
if [ -d "$WT" ]; then ok "discard: default keeps the worktree on disk"; else bad "discard: worktree vanished without --discard"; fi
if git -C "$R" show-ref --verify --quiet refs/heads/phase11a; then ok "discard: default keeps the phase branch"; else bad "discard: phase branch vanished without --discard"; fi

# 11b. success WITH --discard: both are removed.
R="$ROOT/r11b"; WT="$ROOT/wt11b"
fresh_repo "$R"
new_phase "$R" "$WT" phase11b
printf 'impl\n' > "$WT/source/a.txt"
( cd "$R" && "$HARVEST" "$WT" integration --label discard --discard -- 'source/**' >/dev/null )
if [ -d "$WT" ]; then bad "discard: worktree still on disk after --discard"; else ok "discard: worktree removed after a successful --discard"; fi
if git -C "$R" show-ref --verify --quiet refs/heads/phase11b; then bad "discard: phase branch still exists after --discard"; else ok "discard: phase branch removed after a successful --discard"; fi

# 11c. FAILED harvest (empty diff) WITH --discard: nothing is removed —
#      discard only fires after success.
R="$ROOT/r11c"; WT="$ROOT/wt11c"
fresh_repo "$R"
new_phase "$R" "$WT" phase11c
printf 'irrelevant\n' > "$WT/tests/a.test.txt"
rc=0; ( cd "$R" && "$HARVEST" "$WT" integration --label nodiscard --discard -- 'source/**' >/dev/null 2>&1 ) || rc=$?
eq "discard/on-failure: still exits 6 (empty)" "$rc" "6"
if [ -d "$WT" ]; then ok "discard/on-failure: worktree NOT removed on a failed (empty-diff) harvest"; else bad "discard/on-failure: worktree was removed despite failure"; fi
if git -C "$R" show-ref --verify --quiet refs/heads/phase11c; then ok "discard/on-failure: branch NOT removed on a failed (empty-diff) harvest"; else bad "discard/on-failure: branch was removed despite failure"; fi

# ═══════════════════════════════════════════════════════════════════════════
# Stub-guard — the assertions above must be sensitive to real filtering and
# real ref-writing, or they were never testing anything (this repo's
# documented vacuous-assertion trap). Each stub is a copy of the real script
# with one mechanism broken, run against the SAME scenario as a real test
# above; the assertion that passed above must FAIL under the stub.
# ═══════════════════════════════════════════════════════════════════════════

ne "stub-guard: sanity — the harvest script is non-empty" "$(wc -l < "$HARVEST" | tr -d ' ')" "0"

# --- stub 1: the owned-path filter accepts everything (drops the pathspec
#     restriction from the owned-diff computation) ---------------------------
STUB_ACCEPT_ALL="$ROOT/harvest-stub-accept-all.sh"
sed 's#^git diff --no-renames --name-only "\$cut_sha" "\$worktree_tree" -- "\${PATHSPECS\[@\]}" \\$#git diff --no-renames --name-only "$cut_sha" "$worktree_tree" \\#' \
  "$HARVEST" > "$STUB_ACCEPT_ALL"
chmod +x "$STUB_ACCEPT_ALL"
ne "stub-guard: accept-all stub actually differs from the real script" \
  "$(diff -q "$STUB_ACCEPT_ALL" "$HARVEST" >/dev/null 2>&1; echo $?)" "0"
if bash -n "$STUB_ACCEPT_ALL" 2>/dev/null; then
  ok "stub-guard: accept-all stub is syntactically valid (a real behaviour change, not a crash)"
else
  bad "stub-guard: accept-all stub failed to parse — it would prove nothing"
fi

R="$ROOT/rstub1"; WT="$ROOT/wtstub1"
fresh_repo "$R"
new_phase "$R" "$WT" phasestub1
printf 'new-test\n' > "$WT/tests/new.test.txt"
printf 'tester-touched-source\n' > "$WT/source/a.txt"
( cd "$R" && "$STUB_ACCEPT_ALL" "$WT" integration --label stub -- 'tests/**' >/dev/null 2>&1 )
if [ "$(git -C "$R" show integration:source/a.txt)" = "orig" ]; then
  bad "stub-guard: accept-all stub STILL respected the freeze (assertion 4 would be vacuous)"
else
  ok "stub-guard: accept-all stub leaks source/a.txt through — proves test 4 was real"
fi

# --- stub 2: the final ref update is a no-op (the commit never lands) ------
# The trailing "\\" in the replacement is load-bearing: it preserves the
# line-continuation onto the `|| die_code ...` line below, so the stub is a
# true semantic no-op (git update-ref -> true, everything else unchanged) —
# not a syntax error that merely crashes before doing anything. The bash -n
# check right after is what makes that distinction testable rather than
# assumed.
STUB_NOOP_UPDATE="$ROOT/harvest-stub-noop-update.sh"
sed 's#^git update-ref "refs/heads/\$BRANCH" "\$new_commit" "\$old_tip" \\$#true "refs/heads/$BRANCH" "$new_commit" "$old_tip" \\#' \
  "$HARVEST" > "$STUB_NOOP_UPDATE"
chmod +x "$STUB_NOOP_UPDATE"
ne "stub-guard: noop-update stub actually differs from the real script" \
  "$(diff -q "$STUB_NOOP_UPDATE" "$HARVEST" >/dev/null 2>&1; echo $?)" "0"
if bash -n "$STUB_NOOP_UPDATE" 2>/dev/null; then
  ok "stub-guard: noop-update stub is syntactically valid (a real no-op, not a crash)"
else
  bad "stub-guard: noop-update stub failed to parse — it would prove nothing"
fi

R="$ROOT/rstub2"; WT="$ROOT/wtstub2"
fresh_repo "$R"
new_phase "$R" "$WT" phasestub2
printf 'impl\n' > "$WT/source/a.txt"
before="$(tip_sha "$R")"
( cd "$R" && "$STUB_NOOP_UPDATE" "$WT" integration --label stub -- 'source/**' >/dev/null 2>&1 )
if [ "$(tip_sha "$R")" = "$before" ]; then
  ok "stub-guard: noop-update stub leaves the ref alone — proves test 1's tip-moved check was real"
else
  bad "stub-guard: noop-update stub still moved the ref (assertion would be vacuous)"
fi

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
