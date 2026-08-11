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

"$PROJECT_ROOT/.inspire/bin/review.sh" inspire_kb/04_domain || exit 2

# Trust is a signal, never a gate: a project without the tool (pre-0.6) prints
# nothing, and no outcome here may change this hook's own exit code.
if [ -f "$PROJECT_ROOT/.inspire/bin/trust.sh" ]; then
  ( bash "$PROJECT_ROOT/.inspire/bin/trust.sh" report --summary ) || true
fi
