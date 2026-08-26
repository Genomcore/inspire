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
# Severity is lifecycle-progressive, because TDD writes the spec before the test:
#   draft            → warning (the test is legitimately not written yet)
#   accepted, stable → error   (the contract is closed; an untested clause is a lie)
#   superseded       → skipped (no longer authoritative)
#
# Like `escape-hatch-ratchet.sh`, this rule reads `source/` as well as the KB, and is
# deliberately NOT in `review.sh`'s default list: `/inspire_domain review` is a
# knowledge-base review. Invoked by `pre-pr.sh` and by `/inspire_code review`.
#
# Config (env, all optional): SDD_TEST_SCOPE · SDD_TEST_GLOBS, defined in `_lib.sh` and
# shared with `criteria-have-tests.sh` — the discovery logic lives there precisely so the
# two gates cannot drift apart on what counts as a test file.
#
# Usage:
#   .inspire/bin/declared-errors-tested.sh                    # whole tree
#   .inspire/bin/declared-errors-tested.sh inspire_kb/04_domain/analytics

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"
TEST_SCOPE="$SDD_TEST_SCOPE"

if [ ! -d "$TEST_SCOPE" ]; then
  sdd_finding "warning" "declared-errors-tested" "$TEST_SCOPE" \
    "test scope does not exist — no declared error can be verified as tested (set SDD_TEST_SCOPE, or ignore while the project has no code yet)"
  sdd_count_warning
  sdd_exit_with_counters
  exit $?
fi

# ─────────────────────────────────────────────────────────────────────────────
# Collect the test files once. Rebuilding this per error code would re-walk the
# tree for every bullet in the tree.
# ─────────────────────────────────────────────────────────────────────────────

TEST_FILES="$(mktemp -t declared-errors-tests.XXXXXX)"
trap 'rm -f "$TEST_FILES"' EXIT
sdd_find_test_files > "$TEST_FILES"

# Same suppression as `criteria-have-tests.sh`, for the same reason: with zero test
# files every declared code is untested by construction, and a finding per code
# would bury the one actionable signal. The two gates share the discovery logic so
# they cannot drift on WHAT a test file is; this keeps them agreeing on what to do
# when there are NONE.
if [ ! -s "$TEST_FILES" ]; then
  sdd_finding "warning" "declared-errors-tested" "$TEST_SCOPE" \
    "no test files found — every declared error below is untested by construction, so the per-code findings are suppressed to keep the real signal readable"
  sdd_count_warning
  sdd_exit_with_counters
  exit $?
fi

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
  severity="$(sdd_progressive_severity "$lifecycle")"

  local codes
  codes="$(sdd_body_section "$file" "Errors" \
    | awk 'match($0, /^-[[:space:]]+`[A-Za-z0-9_.:-]+`/) {
             s = substr($0, RSTART, RLENGTH)
             gsub(/^-[[:space:]]+`|`$/, "", s)
             print s
           }')"

  [ -z "$codes" ] && return 0

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

sdd_exit_with_counters
