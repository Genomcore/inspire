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

staged_all=$(git diff --cached --name-only 2>/dev/null || true)

# Staged domain files: entities and actions, found by their typed extension anywhere
# under the spec root (adr-kb-structure D4).
staged_files=$(echo "$staged_all" | grep -E '^inspire_kb/01_spec/.+\.(entity|action)\.md$' || true)

[ -n "$staged_files" ] || exit 0

# Affected modules — read from each staged file's id (`auth::user::create` → auth),
# never from the directory it sits in. Every entity and action of those modules is
# in the gate's reach; nothing else is.
in_reach=$(mktemp)
findings_file=$(mktemp)
blockers=$(mktemp)
trap 'rm -f "$blockers" "$findings_file" "$in_reach"' EXIT
module_of() { yq --front-matter=extract '.id // ""' "$1" 2>/dev/null | sed 's/::.*//; s/\..*//'; }
modules=$(echo "$staged_files" | while IFS= read -r f; do [ -f "$f" ] && module_of "$f"; done | grep -v '^$' | sort -u)
find inspire_kb/01_spec -type f \( -name '*.entity.md' -o -name '*.action.md' \) 2>/dev/null \
  | while IFS= read -r f; do
      m="$(module_of "$f")"
      printf '%s\n' "$modules" | grep -qxF "$m" && printf '%s\n' "$f"
    done > "$in_reach"

# Run the review for graph correctness. Resource-coherence is a stricter
# whole-tree check left to pre-PR; per-commit only enforces the rules that
# don't depend on cross-resource field aggregation.
SDD_REVIEW_RULES="acyclic-deps.sh stable-blockers.sh" \
  "$PROJECT_ROOT/.inspire/bin/review.sh" inspire_kb/01_spec 2>"$findings_file" >/dev/null || true

# Filter to error findings whose target is an entity or action of a staged module.
jq -c --rawfile reach "$in_reach" '
  select(.severity == "error" and (.target as $t | ($reach | split("\n") | index($t)) != null))
' "$findings_file" 2>/dev/null >> "$blockers"

[ -s "$blockers" ] || exit 0

# Render the findings on stderr and block.
{
  echo ""
  echo "pre-commit: blocked —"
  jq -r '"  - [\(.severity)] \(.rule) — \(.target)\n    \(.message)"' "$blockers"
} >&2
exit 2
