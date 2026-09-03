#!/usr/bin/env bash
# Input guards: each reports success while doing the wrong thing without one.
# Moved from test-materialize.sh:760-869.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

# The released baseline this block detects against — why a v0.6.0 fixture and
# not the current tree is spelled out in 01-init-current-tree.sh.
FIXTURE_VERSION="0.6.0"
FIXTURE_MANIFEST="$PLUGIN_ROOT/manifests/$FIXTURE_VERSION.json"
FIXTURE_WORK="$(mktemp -d)"
# The tag is spelled out: run.sh greps these call sites for what to pre-build.
FIXTURE_BASE="$(fixture_from_tag v0.6.0 "$FIXTURE_WORK" "$REPO")"
# fixture_copy <dest> — a private copy of the baseline, for one block to mutate.
fixture_copy() { mkdir -p "$1" && cp -R "$FIXTURE_BASE/." "$1/"; }

# ---------------------------------------------------------------------------
# Input guards. Each of these reports SUCCESS while doing the wrong thing if
# its guard is removed — that is why they are here rather than left to review.
# ---------------------------------------------------------------------------

# A --plugin-root that is a directory but not a plugin: every consumer of
# base/ degrades silently, so without the guard this exits 0 having installed
# nothing, and leaves a lock that makes init refuse forever.
gp="$(mktemp -d)/proj"; mkdir -p "$gp"; ( cd "$gp" && git init -q )
notplugin="$(mktemp -d)"
"$SCRIPT" --mode init --plugin-root "$notplugin" --project-root "$gp" >/dev/null 2>&1
rc_notplugin=$?
check "guard: non-plugin --plugin-root exits 1"        "[ '$rc_notplugin' = 1 ]"
check "guard: non-plugin --plugin-root writes no lock" "[ ! -f '$gp/.inspire.lock' ]"
check "guard: non-plugin --plugin-root writes no .gitignore" "[ ! -f '$gp/.gitignore' ]"
check "guard: non-plugin --plugin-root copies nothing" "[ ! -d '$gp/.claude/skills' ]"

# --skip is fed from drift-check echoing the lock's keys verbatim, so a
# corrupted lock must not become an rm -rf outside the project root.
#
# On a v0.6.0 fixture rather than on $gp. $gp carries no runtime at all — the
# init above was refused — so its version cannot be identified and `update`
# exits 1 there whatever --skip says, a BENIGN one included (measured). Both
# assertions passed without the guard ever running. On a project that updates
# cleanly the rc-1 has one remaining explanation, and the benign call below says
# so out loud rather than leaving it implied.
skp="$(mktemp -d)/skproj"
fixture_copy "$skp"
sk_lock_before="$(shasum -a 256 "$skp/.inspire.lock" | cut -d' ' -f1)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$skp" \
  --source-root source --prototype-root prototype \
  --skip '.claude/skills/../../../ESCAPE' >/dev/null 2>&1
rc_traverse=$?
check "guard: --skip containing .. is rejected" "[ '$rc_traverse' = 1 ]"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$skp" \
  --source-root source --prototype-root prototype \
  --skip '/etc/passwd' >/dev/null 2>&1
rc_abs=$?
check "guard: absolute --skip is rejected"      "[ '$rc_abs' = 1 ]"
# A guard that refused after clobbering would still exit 1. It must refuse
# BEFORE anything is written — which is also what leaves the project pristine
# for the control call below, so the three runs differ in their argument alone.
check "guard: a rejected --skip wrote nothing" \
  "[ '$sk_lock_before' = \"\$(shasum -a 256 '$skp/.inspire.lock' | cut -d' ' -f1)\" ]"
# The control: same project, same command, a --skip the guard must accept.
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$skp" \
  --source-root source --prototype-root prototype \
  --skip '.claude/skills/inspire-domain/SKILL.md' >/dev/null 2>&1
rc_benign=$?
check "guard: a benign --skip on the same project exits 0" "[ '$rc_benign' = 0 ]"
rm -rf "$(dirname "$skp")"

# A pre-0.3 *lock* (no `files` map, no actual v0.2 tree behind it — just the
# lock file itself) used to be refused outright by require_v03_lock. Task 12
# deletes that guard on purpose: "a pre-0.3 project is no longer refused, it
# is the longest chain" — detect_version and the hop chain are what decide
# now, not a lock-shape check. This fixture has no real content behind its
# lock, though, so detect_version still refuses it, just for a different
# reason (it cannot identify ANY version from an empty tree) and with a
# different exit code: 1 (precondition failure), not the old 2 (failure
# after writing began — which never applied here anyway, since the old guard
# fired before anything was written).
v2p="$(mktemp -d)/proj"; mkdir -p "$v2p"; ( cd "$v2p" && git init -q )
printf '{"inspire_version":"0.2.1","released":"2026-07-20","template_sha":"abc"}\n' > "$v2p/.inspire.lock"
v2err="$("$SCRIPT" --mode drift-check --plugin-root "$PLUGIN_ROOT" --project-root "$v2p" 2>&1 >/dev/null)"
rc_v2drift=$?
check "guard: pre-0.3 lock — plan can't identify an empty tree (rc)" "[ '$rc_v2drift' = 1 ]"
check "guard: pre-0.3 lock — plan explains why" \
  "printf '%s' \"\$v2err\" | grep -qi 'cannot identify'"
# require_v03_lock's call site inside run_materialize was deleted in Task 12,
# which left `update` running the old blind-copy path for one release: it wrote
# the v0.3 runtime over this fixture, exiting 0, on the strength of nothing but
# a lock file claiming a version. Task 13 wires update through the same
# detect → verify → hop → classify → apply pipeline as `plan`, so the SAME
# refusal now applies to both: an unidentifiable tree is a precondition
# failure, before a byte is written, and the lock is never believed.
#
# These two assertions previously asserted rc = 0 and "the runtime is now on
# disk" — they were tripwires encoding the gap as if it were correct, and they
# had to flip.
v2lock_before="$(shasum -a 256 "$v2p/.inspire.lock" | cut -d' ' -f1)"
v2uerr="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$v2p" 2>&1 >/dev/null)"
rc_v2update=$?
check "guard: pre-0.3 lock — update refuses an unidentifiable tree (rc)" "[ '$rc_v2update' = 1 ]"
check "guard: pre-0.3 lock — update explains why, as plan does" \
  "printf '%s' \"\$v2uerr\" | grep -qi 'cannot identify'"
check "guard: pre-0.3 lock — update wrote no runtime" \
  "[ ! -d '$v2p/.claude/skills' ] && [ ! -d '$v2p/.inspire/bin' ]"
check "guard: pre-0.3 lock — update did not rewrite the lock" \
  "[ '$v2lock_before' = \"\$(shasum -a 256 '$v2p/.inspire.lock' | cut -d' ' -f1)\" ]"
check "guard: pre-0.3 lock — update seeded no KB beside it" "[ ! -e '$v2p/inspire_kb' ]"

# The guard must not fire on a real post-0.3 lock — a false positive here would
# break every legitimate update. A v0.6.0 fixture IS that project: a real
# release, a real lock, and a tree its own manifest identifies at 100%. Init'ing
# from the current tree instead put this pair on the 50% floor, one added
# base/ file away from failing for a reason that has nothing to do with the
# guard under test.
okp="$(mktemp -d)/proj"
fixture_copy "$okp"
"$SCRIPT" --mode drift-check --plugin-root "$PLUGIN_ROOT" --project-root "$okp" >/dev/null 2>&1
rc_okdrift=$?
check "guard: real v0.3 lock still drift-checks" "[ '$rc_okdrift' = 0 ]"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$okp" >/dev/null 2>&1
rc_okupdate=$?
check "guard: real v0.3 lock still updates"      "[ '$rc_okupdate' = 0 ]"
kb_expect="$(find "$PLUGIN_ROOT/base/kb" -type f | wc -l | tr -d ' ')"
check "guard: real v0.3 update kept the KB" \
  "[ \"\$(find '$okp/inspire_kb' -type f | wc -l | tr -d ' ')\" -ge '$kb_expect' ]"

rm -rf "$(dirname "$gp")" "$(dirname "$v2p")" "$(dirname "$okp")" "$notplugin"
fixture_cleanup "$FIXTURE_WORK"
summary
