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
blockers=$(mktemp)
trap 'rm -f "$blockers"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
# Gate 1 — the escape-hatch ratchet (product code, not the KB).
#
# Only runs when the commit touches a configured scope directory: a preexisting
# breach must not block an unrelated commit, the same reason the SDD half below
# filters to staged modules. See quality-gates.md Rule 4.
# ─────────────────────────────────────────────────────────────────────────────

hatch_config="${ESCAPE_HATCH_CONFIG:-.escape-hatches.json}"
if [ -f "$hatch_config" ] && [ -n "$staged_all" ]; then
  touches_scope=false
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    dir="${dir%/}"
    # A scope of "." is the whole repo (source_root: . — brownfield, code at the
    # root), so any staged file is in scope. For everything else, match the
    # prefix LITERALLY via a quoted case pattern — a regex here would let a
    # scope of "." match almost nothing (`^./` anchors one arbitrary character)
    # and any metacharacter in a scope entry corrupt the match.
    if [ "$dir" = "." ]; then
      touches_scope=true
      break
    fi
    while IFS= read -r staged; do
      [ -z "$staged" ] && continue
      case "$staged" in "$dir"/*) touches_scope=true; break ;; esac
    done <<< "$staged_all"
    [ "$touches_scope" = true ] && break
  done < <(jq -r '.scope[]? // empty' "$hatch_config" 2>/dev/null)

  if $touches_scope; then
    hatch_script="$PROJECT_ROOT/.inspire/bin/escape-hatch-ratchet.sh"
    if [ ! -x "$hatch_script" ]; then
      # A configured gate whose enforcer is missing must fail loudly. Swallowing
      # this is how a ratchet becomes decoration: the config says the ceiling is
      # enforced, and nothing enforces it.
      printf '%s\n' "$(jq -nc --arg t "$hatch_script" \
        '{severity:"error",rule:"escape-hatch-ratchet",target:$t,
          message:"config exists but the enforcer is missing — restore it (it is committed to this repo) or remove .escape-hatches.json. A declared gate that silently does not run is worse than no gate."}')" \
        >> "$blockers"
    else
      hatch_findings=$(mktemp)
      "$hatch_script" 2>"$hatch_findings" >/dev/null || true
      jq -c 'select(.severity == "error")' "$hatch_findings" 2>/dev/null >> "$blockers"
      rm -f "$hatch_findings"
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Gate 2 — the SDD graph review, scoped to staged modules.
# ─────────────────────────────────────────────────────────────────────────────

# Staged SDD spec files.
staged_files=$(echo "$staged_all" | grep -E '^inspire_kb/04_domain/.+\.md$' || true)

if [ -z "$staged_files" ]; then
  if [ -s "$blockers" ]; then
    {
      echo ""
      echo "pre-commit: blocked —"
      jq -r '"  - [\(.severity)] \(.rule) — \(.target)\n    \(.message)"' "$blockers"
    } >&2
    exit 2
  fi
  exit 0
fi

# Affected modules — top-level dirs under inspire_kb/04_domain/ that hold a staged file.
# e.g. inspire_kb/04_domain/auth/user/create.md → inspire_kb/04_domain/auth
# cut -d/ -f1-3 yields "inspire_kb/04_domain/{module}" for files under inspire_kb/04_domain/.
modules=$(echo "$staged_files" | cut -d/ -f1-3 | sort -u)
modules_pattern=$(echo "$modules" | tr '\n' '|' | sed 's/|$//')

# Run the review for graph correctness. Resource-coherence is a stricter
# whole-tree check left to pre-PR; per-commit only enforces the rules that
# don't depend on cross-resource field aggregation.
findings_file=$(mktemp)
trap 'rm -f "$blockers" "$findings_file"' EXIT
SDD_REVIEW_RULES="acyclic-deps.sh stable-blockers.sh" \
  "$PROJECT_ROOT/.inspire/bin/review.sh" inspire_kb/04_domain 2>"$findings_file" >/dev/null || true

# Filter to error findings whose target is inside a staged module.
# Targets are paths under inspire_kb/04_domain/{module}/...; the pattern matches the
# module prefix extracted above (e.g. "inspire_kb/04_domain/auth").
jq -c --arg pat "^($modules_pattern)/" '
  select(.severity == "error" and (.target | test($pat)))
' "$findings_file" 2>/dev/null >> "$blockers"

[ -s "$blockers" ] || exit 0

# Render every gate's findings on stderr and block.
{
  echo ""
  echo "pre-commit: blocked —"
  jq -r '"  - [\(.severity)] \(.rule) — \(.target)\n    \(.message)"' "$blockers"
} >&2
exit 2
