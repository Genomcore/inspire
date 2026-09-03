#!/usr/bin/env bash
# The chain.
# Moved from test-upgrade.sh:594-651.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/hop-ops.sh"

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

summary
