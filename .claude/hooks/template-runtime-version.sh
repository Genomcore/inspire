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
MARKETPLACE=".claude-plugin/marketplace.json"

# Paths under plugin/ that are NOT the runtime a fork consumes. Everything else
# counts — including skill prose, because a skill IS its prompt. The plugin
# manifest is exempt (it is the version being bumped), as is base/bin/test/
# and test/, which never materialize into a project. plugin/scripts/ is NOT
# exempt: it is the materialization script that determines how every install
# behaves, so a change to it must require a version bump like everything else.
#
# plugin/manifests/ is deliberately NOT exempt either. A manifest is the only
# record of what INSPIRE shipped at a version, and every upgrade decides whether
# a file is the operator's edit or merely stale by asking it. Editing one changes
# what every future install believes we shipped, which is as load-bearing as
# changing the payload itself.
EXEMPT_RE="^plugin/(\.claude-plugin/plugin\.json|base/bin/test/.*|test/.*)$"

GEN="plugin/scripts/gen-manifest.sh"

# The version being released must ship its own manifest, and that manifest must
# describe the tree it ships with. Without this, a release can go out whose
# manifest is absent or stale — and a stale manifest lies in the direction that
# loses work: it reports an operator's edit as a file INSPIRE never shipped, or a
# file we did ship as one we didn't.
#
# WHY THE `commit` FIELD IS EXCLUDED FROM THE COMPARISON — this is the whole
# trick, and getting it wrong makes the guard unsatisfiable. The manifest for the
# release being prepared is generated from the commit carrying the version bump,
# because the tag does not exist yet: it is only cut once this PR merges. So
# `commit` records whatever HEAD was at generation time — and committing the
# manifest itself moves HEAD past that point. Compare the field and the guard
# demands a regeneration whose own commit invalidates it, forever. Everything
# else (version, released, layout, and the files map that actually matters) is
# invariant under that, because none of it lives under plugin/base/.
#
# Returns 0 pass / 1 fail; prints its own report on failure.
check_manifest() {
  local head="$1" version="$2" changed="$3" want have
  # Split from the line above deliberately: `local` is a builtin, so every one of
  # its assignment words is expanded BEFORE any assignment takes effect. Deriving
  # `path` from `$version` in the same command reads an unset variable, which under
  # `set -u` aborts the function outright.
  local path="plugin/manifests/$version.json"

  if ! git cat-file -e "$head:$GEN" 2>/dev/null; then
    echo "  (no $GEN at $head — manifest check skipped)"
    return 0
  fi

  if ! git cat-file -e "$head:$path" 2>/dev/null; then
    {
      echo ""
      echo "Release $version ships no manifest — blocking the PR."
      echo ""
      echo "  missing: $path"
      echo ""
      echo "  Every released version needs one: it is the only record of what"
      echo "  INSPIRE shipped, and the next upgrade uses it to tell an operator's"
      echo "  edit apart from a file that is merely stale. .inspire.lock cannot"
      echo "  answer that — it lives on the operator's machine."
      echo ""
      echo "  Generate it from the commit carrying the bump (the tag comes later,"
      echo "  on merge):"
      echo ""
      echo "    bash $GEN --tag HEAD --repo . > $path"
      echo ""
    }
    return 1
  fi

  want="$(bash "$GEN" --tag "$head" --repo . 2>/dev/null | jq -S 'del(.commit)' 2>/dev/null)"
  have="$(git show "$head:$path" 2>/dev/null | jq -S 'del(.commit)' 2>/dev/null)"

  if [ -z "$want" ]; then
    echo "  (cannot regenerate $path at $head — manifest check inconclusive)"
    return 0
  fi

  if [ "$want" != "$have" ]; then
    {
      echo ""
      echo "$path does not describe the tree it ships with — blocking the PR."
      echo ""
      echo "  Changed runtime files:"
      printf '%s\n' "$changed" | sed 's/^/    · /'
      echo ""
      echo "  The manifest was generated before some of these landed, so it now"
      echo "  claims a set of hashes INSPIRE does not actually ship. An upgrade"
      echo "  reading it would misattribute those files — reporting our own stale"
      echo "  content as the operator's edit, or their edit as content we shipped."
      echo ""
      echo "  Regenerate and commit it:"
      echo ""
      echo "    bash $GEN --tag HEAD --repo . > $path"
      echo ""
      echo "  (The \`commit\` field is not compared — it necessarily names the"
      echo "  commit before the manifest's own, so it can never match HEAD.)"
      echo ""
    }
    return 1
  fi

  echo "✓ $path matches the tree"
  return 0
}

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

  # The release identity is duplicated: plugin.json is what a materialized
  # project records in .inspire.lock, marketplace.json is what `/plugin install`
  # resolves. If they disagree, an install and its provenance record disagree.
  local mkt_version
  mkt_version="$(git show "$head:$MARKETPLACE" 2>/dev/null \
    | jq -r '.plugins[]? | select(.name == "inspire") | .version // empty' 2>/dev/null || true)"
  if [ -n "$mkt_version" ] && [ "$mkt_version" != "$head_version" ]; then
    {
      echo ""
      echo "Release identity is inconsistent — blocking the PR."
      echo ""
      echo "  $MANIFEST      version: $head_version"
      echo "  $MARKETPLACE   version: $mkt_version"
      echo ""
      echo "  plugin.json is what a project freezes into .inspire.lock;"
      echo "  marketplace.json is what /plugin install resolves. Bump both."
      echo ""
    }
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
    check_manifest "$head" "$head_version" "$runtime_changed" || return 1
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

  check_manifest "$head" "$head_version" "$runtime_changed" || return 1

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
