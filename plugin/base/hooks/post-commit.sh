#!/usr/bin/env bash
# .claude/inspire/hooks/post-commit.sh
#
# Routed check, not a registered hook. Invoked by dispatch.sh — never directly —
# on PostToolUse, with the matched command string as $1; it does not read stdin.
# Matches `git commit` invocations and runs the KB review on each KB file the new
# commit contains, in every layer, reporting the findings on those files.
#
# Exit codes follow Claude Code's PostToolUse contract:
#   0 — nothing to report
#   2 — stderr is fed back to the agent; the commit already happened and stays
#
# Worktree self-scoping and stdin parsing are the dispatcher's job, done once
# for every routed check; by the time this script runs, dispatch.sh has already
# `cd`'d to the project root.

set -uo pipefail
PROJECT_ROOT="$(pwd -P)"

committed_kb=$(git diff-tree --no-commit-id --name-only -r --diff-filter=d HEAD 2>/dev/null \
  | grep -E '^inspire_kb/.+\.md$' || true)
[ -n "$committed_kb" ] || exit 0

findings_file=$(mktemp)
report=$(mktemp)
trap 'rm -f "$findings_file" "$report"' EXIT

while IFS= read -r file; do
  [ -z "$file" ] && continue
  "$PROJECT_ROOT/.inspire/bin/review.sh" "$file" 2>"$findings_file" >/dev/null || true
  jq -c --arg f "$file" 'select(.target == $f)' "$findings_file" 2>/dev/null >> "$report"
done <<< "$committed_kb"

[ -s "$report" ] || exit 0

{
  echo ""
  echo "post-commit: the commit went through. The KB review found this in the files it contains —"
  jq -r -s 'unique | sort_by(.target, .severity)[] | "  - [\(.severity)] \(.rule) — \(.target)\n    \(.message)"' "$report"
  echo ""
  echo "Warnings never block. Errors block the pull request, so fix them before opening one."
} >&2
exit 2
