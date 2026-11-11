#!/usr/bin/env bash
# .inspire/bin/declared-errors-tested.sh
#
# Rule: every error an action descriptor declares in `## Errors` is exercised by a
# test. A declared error with no test is a contract nobody checks — the spec promises
# a behavior and nothing anywhere would notice if it disappeared.
#
# How it checks: the error code must appear as a **literal** in a test file. That is
# not a proxy for "a test exists" — it is the wire conventions' own requirement
# (`_references/conventions/`) that a test assert the exact error code rather than a
# loose matcher. Satisfying this rule and satisfying that one are the same act.
#
# Severity follows what the descriptor claims about its implementation:
#   draft, accepted → warning (the contract is still being built; its tests come with it)
#   stable          → error   (the implementation is locked; an untested clause is a lie)
#   superseded      → skipped (no longer authoritative)
#
# Like `escape-hatch-ratchet.sh`, this rule reads `source/` as well as the KB, and is
# deliberately NOT in `review.sh`'s default list: `/inspire-domain review` is a
# knowledge-base review. Invoked by `pre-pr.sh`.
#
# Config (env, all optional): SDD_TEST_SCOPE · SDD_TEST_GLOBS, defined in `_lib.sh` and
# shared with `criteria-have-tests.sh` — the discovery logic lives there precisely so the
# two gates cannot drift apart on what counts as a test file.
#
# Usage:
#   .inspire/bin/declared-errors-tested.sh                    # whole tree
#   .inspire/bin/declared-errors-tested.sh inspire_kb/01_spec/_modules/analytics

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"
TEST_SCOPE="$SDD_TEST_SCOPE"

# ─────────────────────────────────────────────────────────────────────────────
# Collect the test files once. Rebuilding this per error code would re-walk the
# tree for every bullet in the tree.
# ─────────────────────────────────────────────────────────────────────────────

TEST_FILES="$(mktemp -t declared-errors-tests.XXXXXX)"
trap 'rm -f "$TEST_FILES"' EXIT
sdd_find_test_files > "$TEST_FILES"

NO_TESTS=0
[ -s "$TEST_FILES" ] || NO_TESTS=1
UNTESTED_CODES=0
UNTESTED_ACTIONS=0
UNTESTED_SEVERITY="warning"

# ─────────────────────────────────────────────────────────────────────────────
# Per action: read `## Errors`, extract the leading backticked code from each
# bullet, and look for it in the tests.
# ─────────────────────────────────────────────────────────────────────────────

check_action() {
  local file="$1"

  local lifecycle
  lifecycle="$(sdd_fm_value "$file" '.lifecycle')"
  [ "$lifecycle" = "superseded" ] && return 0

  local severity
  severity="warning"
  [ "$lifecycle" = "stable" ] && severity="error"

  local codes
  codes="$(sdd_body_section "$file" "Errors" \
    | awk 'match($0, /^-[[:space:]]+`[A-Za-z0-9_.:-]+`/) {
             s = substr($0, RSTART, RLENGTH)
             gsub(/^-[[:space:]]+`|`$/, "", s)
             print s
           }')"

  [ -z "$codes" ] && return 0

  if [ "$NO_TESTS" -eq 1 ]; then
    UNTESTED_CODES=$((UNTESTED_CODES + $(printf '%s\n' "$codes" | grep -c .)))
    UNTESTED_ACTIONS=$((UNTESTED_ACTIONS + 1))
    [ "$severity" = "error" ] && UNTESTED_SEVERITY="error"
    return 0
  fi

  while IFS= read -r code; do
    [ -z "$code" ] && continue
    if sdd_literal_in_tests "$code" "$TEST_FILES"; then
      continue
    fi
    sdd_finding "$severity" "declared-errors-tested" "$file" \
      "declared error \`$code\` appears in no test under $TEST_SCOPE — the descriptor promises it and nothing would notice if it vanished (assert the exact code, per the project's wire convention)"
    sdd_count_by_severity "$severity"
  done <<< "$codes"
}

while IFS= read -r action; do
  [ -z "$action" ] && continue
  check_action "$action"
done < <(sdd_find_actions "$SCOPE")

if [ "$UNTESTED_CODES" -gt 0 ]; then
  sdd_finding "$UNTESTED_SEVERITY" "declared-errors-tested" "$TEST_SCOPE" \
    "no test files found — $UNTESTED_CODES declared errors across $UNTESTED_ACTIONS action descriptors appear in no test (one finding stands for them all; it is an error once any of those descriptors is \`stable\`, because no tests is not a pass)"
  sdd_count_by_severity "$UNTESTED_SEVERITY"
fi

sdd_exit_with_counters
