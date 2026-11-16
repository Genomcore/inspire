#!/usr/bin/env bash
# .claude/inspire/hooks/pre-pr.sh
#
# Routed check, not a registered hook. Invoked by dispatch.sh — never directly —
# with the matched command string as $1; it does not read stdin. Matches
# `gh pr create` invocations and runs the full SDD review. Defense-in-depth
# alongside pre-commit: catches the case where a branch carries broken spec
# even though no edit passed through this session's commit hook (amended
# commits, history rewrites, branch checkouts from elsewhere).
#
# Exit codes follow Claude Code's hook contract:
#   0 — allow the tool call
#   2 — block the tool call; stderr is fed back to the agent
#
# Worktree self-scoping and stdin parsing are the dispatcher's job, done once
# for every routed check; by the time this script runs, dispatch.sh has already
# `cd`'d to the project root.

set -uo pipefail
PROJECT_ROOT="$(pwd -P)"   # dispatcher cd'd here

# Every gate runs before the hook decides, rather than exiting on the first
# failure: at PR time the operator wants the whole list in one pass, not one
# finding per re-run.
STATUS=0

"$PROJECT_ROOT/.inspire/bin/review.sh" inspire_kb || STATUS=2

# Every error a descriptor declares must be exercised by a test. Lifecycle-progressive
# on its own (warning at draft and accepted, error at stable), so this can run
# unconditionally: a contract still being built does not block a PR, a locked one does.
errors_tested="$PROJECT_ROOT/.inspire/bin/declared-errors-tested.sh"
[ -x "$errors_tested" ] && { "$errors_tested" inspire_kb/01_spec || STATUS=2; }

# Every acceptance criterion traceable to a test. Same lifecycle-progressive shape:
# a 🟡 Planned feature warns, a feature being worked on or claimed done blocks.
criteria_tested="$PROJECT_ROOT/.inspire/bin/criteria-have-tests.sh"
[ -x "$criteria_tested" ] && { "$criteria_tested" inspire_kb/01_spec || STATUS=2; }

# The decision layer must not claim less than the code delivers: every ADR a 🟢 Implemented
# feature rests on is itself `implemented`. Adopt it green: promote (or demote) the stale
# claims it finds before landing it, because a gate that is red the day it lands is a gate
# people learn to bypass.
adr_maturity="$PROJECT_ROOT/.inspire/bin/adr-maturity-matches-features.sh"
[ -x "$adr_maturity" ] && { "$adr_maturity" inspire_kb/01_spec || STATUS=2; }

# The gate that guards the gates: every quality gate a resolved stack profile declares is
# actually present in the project's config. Cheap (a few greps) and it protects every other
# mechanical rule from quietly ceasing to exist.
profile_gates="$PROJECT_ROOT/.inspire/bin/profile-gates-installed.sh"
[ -x "$profile_gates" ] && { "$profile_gates" || STATUS=2; }

# Trust is a signal, never a gate: a project without the tool (pre-0.6) prints
# nothing, and no outcome here may change this hook's own exit code.
if [ -f "$PROJECT_ROOT/.inspire/bin/trust.sh" ]; then
  ( bash "$PROJECT_ROOT/.inspire/bin/trust.sh" report --summary ) || true
fi

exit $STATUS
