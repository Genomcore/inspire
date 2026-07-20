#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh
#
# Claude PreToolUse Bash hook. Matches `git commit` invocations and runs
# the full SDD review for graph correctness, then surfaces only findings
# whose target sits inside a staged module. Cross-module dependency rules
# (acyclic-deps, stable-blockers) see the whole tree while preexisting
# errors in unrelated modules don't block the commit.
#
# Exit codes follow Claude Code's hook contract:
#   0 — allow the tool call
#   2 — block the tool call; stderr is fed back to the agent
#
# Manual `git commit` from a non-Claude terminal does NOT trigger this
# hook by design — see plan, "manual edits are owned by whoever commits
# them". Server-side enforcement against bypasses lands in CI.
#
# Worktree self-scoping: the harness caches PreToolUse hooks per project,
# so a registration installed by one worktree's settings.json can be
# replayed for a session whose $CLAUDE_PROJECT_DIR points elsewhere. The
# guard below compares the hook's home worktree (derived from $0) against
# the firing session's project dir and silently no-ops on mismatch.

set -uo pipefail

HOOK_DIR="$(cd -P "$(dirname "$0")" && pwd -P)"
HOME_ROOT="$(cd -P "$HOOK_DIR/../.." && pwd -P)"

SESSION_ROOT_RAW="${CLAUDE_PROJECT_DIR:-$PWD}"
SESSION_ROOT="$(cd -P "$SESSION_ROOT_RAW" 2>/dev/null && pwd -P)" || SESSION_ROOT=""

[ -n "$SESSION_ROOT" ] && [ "$SESSION_ROOT" = "$HOME_ROOT" ] || exit 0

PROJECT_ROOT="$HOME_ROOT"

HOOK_INPUT=$(cat)
cmd=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

cd "$PROJECT_ROOT"

# Staged SDD spec files.
staged_files=$(git diff --cached --name-only 2>/dev/null \
  | grep -E '^.inspire_kb/04_specs/.+\.md$' \
  || true)

[ -z "$staged_files" ] && exit 0

# Affected modules — top-level dirs under .inspire_kb/04_specs/ that hold a staged file.
# e.g. .inspire_kb/04_specs/auth/user/create.md → .inspire_kb/04_specs/auth
# cut -d/ -f1-3 yields ".inspire_kb/04_specs/{module}" for files under .inspire_kb/04_specs/.
modules=$(echo "$staged_files" | cut -d/ -f1-3 | sort -u)
modules_pattern=$(echo "$modules" | tr '\n' '|' | sed 's/|$//')

# Run the review for graph correctness. Resource-coherence is a stricter
# whole-tree check left to pre-PR; per-commit only enforces the rules that
# don't depend on cross-resource field aggregation.
findings_file=$(mktemp)
trap 'rm -f "$findings_file"' EXIT
SDD_REVIEW_RULES="acyclic-deps.sh stable-blockers.sh" \
  "$PROJECT_ROOT/.claude/bin/review.sh" .inspire_kb/04_specs 2>"$findings_file" >/dev/null || true

# Filter to error findings whose target is inside a staged module.
# Targets are paths under .inspire_kb/04_specs/{module}/...; the pattern matches the
# module prefix extracted above (e.g. ".inspire_kb/04_specs/auth").
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
