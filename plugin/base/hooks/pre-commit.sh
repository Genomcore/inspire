#!/usr/bin/env bash
# .claude/inspire/hooks/pre-commit.sh
#
# Routed check, not a registered hook. Invoked by dispatch.sh — never directly —
# with the matched command string as $1; it does not read stdin. Matches
# `git commit` invocations and runs the full SDD review for graph correctness,
# then surfaces only findings whose target sits inside a staged module.
# Cross-module dependency rules (acyclic-deps, stable-blockers) see the whole
# tree while preexisting errors in unrelated modules don't block the commit.
#
# Exit codes follow Claude Code's hook contract:
#   0 — allow the tool call
#   2 — block the tool call; stderr is fed back to the agent
#
# Manual `git commit` from a non-Claude terminal does NOT trigger this
# hook by design — see plan, "manual edits are owned by whoever commits
# them". Server-side enforcement against bypasses lands in CI.
#
# Worktree self-scoping and stdin parsing are the dispatcher's job, done once
# for every routed check; by the time this script runs, dispatch.sh has already
# `cd`'d to the project root.

set -uo pipefail
PROJECT_ROOT="$(pwd -P)"   # dispatcher cd'd here

# Staged SDD spec files.
staged_files=$(git diff --cached --name-only 2>/dev/null \
  | grep -E '^inspire_kb/04_domain/.+\.md$' \
  || true)

[ -z "$staged_files" ] && exit 0

# Affected modules — top-level dirs under inspire_kb/04_domain/ that hold a staged file.
# e.g. inspire_kb/04_domain/auth/user/create.md → inspire_kb/04_domain/auth
# cut -d/ -f1-3 yields "inspire_kb/04_domain/{module}" for files under inspire_kb/04_domain/.
modules=$(echo "$staged_files" | cut -d/ -f1-3 | sort -u)
modules_pattern=$(echo "$modules" | tr '\n' '|' | sed 's/|$//')

# Run the review for graph correctness. Resource-coherence is a stricter
# whole-tree check left to pre-PR; per-commit only enforces the rules that
# don't depend on cross-resource field aggregation.
findings_file=$(mktemp)
trap 'rm -f "$findings_file"' EXIT
SDD_REVIEW_RULES="acyclic-deps.sh stable-blockers.sh" \
  "$PROJECT_ROOT/.inspire/bin/review.sh" inspire_kb/04_domain 2>"$findings_file" >/dev/null || true

# Filter to error findings whose target is inside a staged module.
# Targets are paths under inspire_kb/04_domain/{module}/...; the pattern matches the
# module prefix extracted above (e.g. "inspire_kb/04_domain/auth").
relevant=$(jq -c --arg pat "^($modules_pattern)/" '
  select(.severity == "error" and (.target | test($pat)))
' "$findings_file" 2>/dev/null)

[ -z "$relevant" ] && exit 0

# Render filtered findings on stderr and block.
{
  echo ""
  echo "pre-commit: SDD review found errors in staged scope:"
  echo "$relevant" | jq -r '"  - [\(.severity)] \(.rule) — \(.target)\n    \(.message)"'
} >&2
exit 2
