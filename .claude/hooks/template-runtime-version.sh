#!/usr/bin/env bash
# INSPIRE-TEMPLATE-MAINTENANCE — not part of the seeded runtime.
#
# .claude/hooks/template-runtime-version.sh
#
# Release-identity guard for the INSPIRE TEMPLATE REPO ITSELF. If a change
# touches the runtime under plugin/, then plugin/.claude-plugin/plugin.json's
# `version` must move FORWARD — strictly above the base version, and not a
# value some earlier release already tagged — in the same branch. A merely
# *different* string is not enough: 0.3.0 → 0.2.9, or reverting to an
# already-released 0.2.1, would satisfy an inequality while still shipping a
# runtime state under a version string that already names a different one —
# which is what happened between 2fa511b (#5) and d41fd89 (#6), leaving 0.1.0
# naming two runtimes while every fork wrote the same .inspire.lock value
# regardless.
#
# WHY THIS LIVES IN .claude/ AND NOT plugin/
#   plugin/ is the SEED — /inspire:init materializes it into a fork's
#   .claude/ and inspire_kb/. This hook is about maintaining the template,
#   and a fork consumes the plugin manifest via .inspire.lock but never
#   authors it. So it is template-scoped, and it never ships inside plugin/
#   (sentinel-checked on the marker in line 1) the same way the template's
#   own README.md never reaches a fork.
#
# Claude PreToolUse Bash hook. Exit codes follow the hook contract:
#   0 — allow the tool call
#   2 — block the tool call; stderr is fed back to the agent
#
# Self-test (no hook harness needed):
#   .claude/hooks/template-runtime-version.sh --check <base-ref> <head-ref>
#   → exit 0 pass, exit 1 fail

set -uo pipefail

MANIFEST="plugin/.claude-plugin/plugin.json"

# Paths under plugin/ that are NOT the runtime a fork consumes. Everything else
# counts — including skill prose, because a skill IS its prompt. The plugin
# manifest is exempt (it is the version being bumped), as is base/bin/test/
# and test/, which never materialize into a project. plugin/scripts/ is NOT
# exempt: it is the materialization script that determines how every install
# behaves, so a change to it must require a version bump like everything else.
EXEMPT_RE="^plugin/(\.claude-plugin/plugin\.json|base/bin/test/.*|test/.*)$"

# Prints the failure report on stdout; returns 0 pass / 1 fail.
check_versions() {
  local base="$1" head="$2" changed runtime_changed base_version head_version highest

  changed="$(git diff --name-only "$base" "$head" -- plugin/ 2>/dev/null)"
  runtime_changed="$(printf '%s\n' "$changed" | grep -vE "$EXEMPT_RE" | grep -E '^plugin/.' || true)"

  if [ -z "$runtime_changed" ]; then
    echo "✓ no runtime change under plugin/ — version bump not required"
    return 0
  fi

  base_version="$(git show "$base:$MANIFEST" 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)"
  head_version="$(git show "$head:$MANIFEST" 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)"

  if [ -z "$head_version" ]; then
    echo "✗ cannot read .version from $MANIFEST at $head"
    return 1
  fi

  # A tagged version has shipped — forks that installed it already recorded
  # it as their provenance. Checked before the base_version-empty branch
  # below: a newly-added manifest naming an already-tagged version is still
  # wrong, even though there is nothing yet to compare it against.
  if git rev-parse -q --verify "refs/tags/v$head_version" >/dev/null 2>&1; then
    {
      echo ""
      echo "Version v$head_version is already tagged — blocking the PR."
      echo ""
      echo "  $MANIFEST version: $head_version"
      echo ""
      echo "  Changed runtime files:"
      printf '%s\n' "$runtime_changed" | sed 's/^/    · /'
      echo ""
      echo "  A tagged version has shipped; reusing it would let two different"
      echo "  runtime states share one version string, and forks that already"
      echo "  installed v$head_version have recorded it as their provenance."
      echo ""
      echo "  Bump \`version\` to a new, untagged value (semver) in $MANIFEST."
      echo ""
    }
    return 1
  fi

  if [ -z "$base_version" ]; then
    echo "✓ runtime changed and version bumped: <none> → $head_version"
    return 0
  fi

  if [ "$base_version" = "$head_version" ]; then
    {
      echo ""
      echo "Runtime changed without a version bump — blocking the PR."
      echo ""
      echo "  $MANIFEST version is still: $head_version"
      echo ""
      echo "  Changed runtime files:"
      printf '%s\n' "$runtime_changed" | sed 's/^/    · /'
      echo ""
      echo "  Bump \`version\` (semver) and \`released\` (YYYY-MM-DD) in $MANIFEST."
      echo "  /inspire:init freezes these into a fork's .inspire.lock and inspire-lesson"
      echo "  stamps them onto every lesson, so a version naming two different runtime"
      echo "  states breaks fork provenance."
      echo ""
      echo "  On merge, tag the result \"v<version>\" and publish a release."
      echo ""
    }
    return 1
  fi

  # A version must move FORWARD. `!=` would accept 0.3.0 → 0.2.9, which is
  # the same provenance corruption this guard exists to prevent: one version
  # naming two runtimes.
  highest="$(printf '%s\n%s\n' "$base_version" "$head_version" | sort -V | tail -1)"
  if [ "$highest" != "$head_version" ]; then
    {
      echo ""
      echo "Version went backwards — blocking the PR."
      echo ""
      echo "  $MANIFEST version: $base_version → $head_version"
      echo ""
      echo "  Changed runtime files:"
      printf '%s\n' "$runtime_changed" | sed 's/^/    · /'
      echo ""
      echo "  A runtime version must move forward, never back — reverting the"
      echo "  string lets two different runtime states share one name, which is"
      echo "  the exact corruption this guard exists to prevent."
      echo ""
      echo "  Bump \`version\` above $base_version (semver) in $MANIFEST."
      echo ""
    }
    return 1
  fi

  echo "✓ runtime changed and version bumped: $base_version → $head_version"
  return 0
}

# ---- self-test mode -------------------------------------------------------
if [ "${1:-}" = "--check" ]; then
  check_versions "${2:?usage: --check <base-ref> <head-ref>}" "${3:?usage: --check <base-ref> <head-ref>}"
  exit $?
fi

# ---- hook mode ------------------------------------------------------------
# Worktree self-scoping: the harness caches PreToolUse hooks per project, so a
# registration installed by one worktree can be replayed for a session whose
# $CLAUDE_PROJECT_DIR points elsewhere. Only act for our own session.
HOOK_DIR="$(cd -P "$(dirname "$0")" && pwd -P)"
HOME_ROOT="$(cd -P "$HOOK_DIR/../.." && pwd -P)"

SESSION_ROOT_RAW="${CLAUDE_PROJECT_DIR:-$PWD}"
SESSION_ROOT="$(cd -P "$SESSION_ROOT_RAW" 2>/dev/null && pwd -P)" || SESSION_ROOT=""

[ -n "$SESSION_ROOT" ] && [ "$SESSION_ROOT" = "$HOME_ROOT" ] || exit 0

HOOK_INPUT=$(cat)
cmd=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

case "$cmd" in
  *"gh pr create"*) ;;
  *) exit 0 ;;
esac

cd "$HOME_ROOT" || exit 0

# Base is the merge-base with main — the PR's actual diff, not everything that
# landed on main since the branch started.
BASE_REF="main"
git show-ref --verify --quiet refs/remotes/origin/main && BASE_REF="origin/main"
base="$(git merge-base "$BASE_REF" HEAD 2>/dev/null)" || exit 0

report="$(check_versions "$base" HEAD)"; rc=$?
[ "$rc" -eq 0 ] && exit 0

printf '%s\n' "$report" >&2
exit 2
