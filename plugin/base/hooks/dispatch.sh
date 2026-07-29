#!/usr/bin/env bash
# .claude/inspire/hooks/dispatch.sh
#
# Single PreToolUse/Bash entry point for the INSPIRE runtime. Parses the hook
# payload once, applies the worktree self-scoping guard once, then routes to the
# matching check by command pattern.
#
# Why one dispatcher: every Bash tool call fires PreToolUse. Registering N hooks
# means N process spawns per command, each re-parsing the same JSON and re-running
# the same guard before most of them decide they have nothing to do. Routing makes
# it one spawn, and adding a check later is a table entry rather than another
# registration.
#
# Exit codes follow Claude Code's hook contract:
#   0 — allow the tool call
#   2 — block the tool call; stderr is fed back to the agent
#
# Depth note: installed at .claude/inspire/hooks/, so the project root is three
# levels up. Getting this wrong makes the guard below never match, which silently
# disables every check.

set -uo pipefail

HOOK_DIR="$(cd -P "$(dirname "$0")" && pwd -P)"
HOME_ROOT="$(cd -P "$HOOK_DIR/../../.." && pwd -P)"

SESSION_ROOT_RAW="${CLAUDE_PROJECT_DIR:-$PWD}"
SESSION_ROOT="$(cd -P "$SESSION_ROOT_RAW" 2>/dev/null && pwd -P)" || SESSION_ROOT=""
[ -n "$SESSION_ROOT" ] && [ "$SESSION_ROOT" = "$HOME_ROOT" ] || exit 0

HOOK_INPUT=$(cat)
cmd=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -n "$cmd" ] || exit 0

cd "$HOME_ROOT" || exit 0

# Routing table: command pattern → check script. First match wins; a check's exit
# code becomes the dispatcher's. Add a row to extend.
case "$cmd" in
  *"git commit"*)   exec "$HOOK_DIR/pre-commit.sh" "$cmd" ;;
  *"gh pr create"*) exec "$HOOK_DIR/pre-pr.sh"     "$cmd" ;;
  *)                exit 0 ;;
esac
