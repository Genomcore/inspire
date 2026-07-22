#!/usr/bin/env bash
# .claude/hooks/session-start.sh
#
# Claude SessionStart hook. Reads the project's declared output language from
# .inspire_kb/00_bootstrap/project.md and injects it into the session as context,
# so EVERY session — regardless of the language the operator converses in — starts
# knowing which language INSPIRE artifacts must be authored in. This is the strong,
# always-present half of the output-language rule; the skills carry the same rule
# as judgment (see .claude/skills/_references/output-language.md).
#
# Output contract (SessionStart): stdout is JSON with
#   {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "…"}}
# additionalContext is prepended to the session context. Exit 0 always — a missing
# project.md just falls back to English; this hook never blocks a session.
#
# Worktree self-scoping: the harness caches hooks per project, so a registration
# installed by one worktree's settings.json can be replayed for a session whose
# $CLAUDE_PROJECT_DIR points elsewhere. The guard below compares the hook's home
# root (derived from $0) against the firing session's project dir and silently
# no-ops on mismatch — mirrors pre-commit.sh / pre-pr.sh.

set -uo pipefail

HOOK_DIR="$(cd -P "$(dirname "$0")" && pwd -P)"
HOME_ROOT="$(cd -P "$HOOK_DIR/../.." && pwd -P)"

SESSION_ROOT_RAW="${CLAUDE_PROJECT_DIR:-$PWD}"
SESSION_ROOT="$(cd -P "$SESSION_ROOT_RAW" 2>/dev/null && pwd -P)" || SESSION_ROOT=""

[ -n "$SESSION_ROOT" ] && [ "$SESSION_ROOT" = "$HOME_ROOT" ] || exit 0

PROJECT_ROOT="$HOME_ROOT"

# Consume stdin (the SessionStart payload) so the runner never sees a broken pipe.
cat >/dev/null 2>&1 || true

PROJECT_FILE="$PROJECT_ROOT/.inspire_kb/00_bootstrap/project.md"

# Read output_language from the frontmatter; default to English if absent/empty.
LANG_VALUE=""
if [ -f "$PROJECT_FILE" ] && command -v yq >/dev/null 2>&1; then
  LANG_VALUE="$(yq --front-matter=extract '.output_language // ""' "$PROJECT_FILE" 2>/dev/null || true)"
fi
[ -n "$LANG_VALUE" ] && [ "$LANG_VALUE" != "null" ] || LANG_VALUE="en"

CONTEXT="INSPIRE output language — \`output_language: ${LANG_VALUE}\`.

When you create or edit any knowledge-base artifact as part of an INSPIRE skill \
(anything under \`.inspire_kb/\`, plus the project \`README.md\` and prototype \
learnings), author the **prose** in \`${LANG_VALUE}\`. This holds regardless of the \
language of this conversation and regardless of the product's own UI i18n: reply \
to the operator in their language, but write the *files* in the project language. \
Machine-read tokens stay verbatim — frontmatter keys and enum values (\`kind\`, \
\`status\`, \`maturity\`, lifecycle states), wikilink target slugs, file/directory \
names, IDs and status-map keys are never translated. See \
\`.claude/skills/_references/output-language.md\` for the full rule."

# Surface the runtime version (best-effort) from .inspire.lock, written by install.sh.
# Appends a short note so every session knows which INSPIRE release it is running and
# that skill learnings captured now will be stamped with it.
INSPIRE_VERSION=""
LOCK_FILE="$PROJECT_ROOT/.inspire.lock"
if [ -f "$LOCK_FILE" ] && command -v jq >/dev/null 2>&1; then
  INSPIRE_VERSION="$(jq -r '.inspire_version // ""' "$LOCK_FILE" 2>/dev/null || true)"
fi
if [ -n "$INSPIRE_VERSION" ] && [ "$INSPIRE_VERSION" != "null" ]; then
  CONTEXT="${CONTEXT}

INSPIRE runtime — version \`${INSPIRE_VERSION}\` (see \`.inspire.lock\`). When a \
session surfaces a generalizable insight about a skill, record it with \
\`/inspire_learn note\`; it is stamped with this runtime version."
fi

# Emit the SessionStart context. Prefer jq for safe JSON escaping; fall back to a
# minimal python escaper if jq is somehow unavailable.
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  ESCAPED="$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)"
  [ -n "$ESCAPED" ] || exit 0
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$ESCAPED"
fi

exit 0
