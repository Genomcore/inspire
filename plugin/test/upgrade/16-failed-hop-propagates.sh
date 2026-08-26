#!/usr/bin/env bash
# A failed hop must propagate, and must never stamp the version.
# Moved from test-upgrade.sh:1162-1231.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/hop-ops.sh"
. "$PLUGIN_ROOT/scripts/lib/chain.sh"
. "$HERE/lib/scratch.sh"

MZ="$PLUGIN_ROOT/scripts/materialize.sh"

# ---- a failed hop must propagate, and must never stamp the version ---------
# `. "$hop" || return 2` CANNOT see this: a sourced script's exit status is its
# LAST command's, and hops/0.3.0.sh ends with hop_report, which always returns 0.
# So run_chain returned 0 whatever happened in the middle and run_materialize's
# `|| exit 2` was dead code. Reproduced with .claude/bin unwritable: all 14
# validator moves failed, every failure was honestly journalled, the run exited
# 0 — and .inspire.lock went 0.2.1 → 0.3.1, claiming a migration that did not
# happen. HOP_FAILED, compared across each hop, is what makes it observable.
#
# chmod 500 again, so the fixture is registered for the same reason the hop-ops
# scratch trees are: `rm -rf` cannot unlink out of a directory it may not write
# to, and the restore below is on the happy path only. fixture_cleanup still does
# the removing when the block completes; the trap only covers an abort inside the
# window, and its `[ -d ]` guard makes the double-up a no-op.
w="$(mktemp -d)"; hopops_scratch "$w"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
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
  # the migration would never be retried. Registered for the same reason as the
  # tree above — this one's restore sits after a materialize.sh call, so the
  # unwritable window spans a whole subprocess.
  w="$(mktemp -d)"; hopops_scratch "$w"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
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

summary
