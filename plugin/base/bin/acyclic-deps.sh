#!/usr/bin/env bash
# .claude/bin/acyclic-deps.sh
#
# Rule: the global action→action `requires` graph must be acyclic and free
# of self-loops. Detects:
#   - self-loops (action requires itself)
#   - cycles (action A → B → ... → A)
#
# Implementation: reads `.requires` lists from each action descriptor,
# strips [[ ]] wikilink wrappers, and pipes (predecessor, successor) pairs
# through `tsort`. BSD macOS tsort silently elides self-loops, so those are
# detected directly before the tsort call.
#
# Severity: error.
#
# Usage:
#   .claude/bin/acyclic-deps.sh                  # scan whole tree
#   .claude/bin/acyclic-deps.sh .inspire_kb/04_domain/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
command -v tsort >/dev/null 2>&1 || {
  echo "error: tsort not found (expected as part of base unix utilities)" >&2
  exit 127
}
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

# Build the id → path index up front so we can resolve names for findings.
sdd_build_id_index "$SCOPE"

EDGES_FILE="$(mktemp -t sdd-edges.XXXXXX)"
STDERR_FILE="$(mktemp -t sdd-tsort-stderr.XXXXXX)"
trap 'rm -f "$EDGES_FILE" "$STDERR_FILE" "${SDD_ID_INDEX_FILE:-}"' EXIT

# Collect (from_id, to_id) pairs from `.requires` lists.
# tsort expects TAB-separated pairs.
while IFS= read -r action; do
  [ -z "$action" ] && continue
  from_id="$(sdd_fm_value "$action" '.id')"
  [ -z "$from_id" ] && continue

  while IFS= read -r req; do
    [ -z "$req" ] && continue
    to_id="$(sdd_unwrap_wikilink "$req")"

    # Self-loops — BSD tsort silently elides these, so detect directly.
    if [ "$from_id" = "$to_id" ]; then
      path="$(sdd_resolve_id "$from_id")"
      sdd_finding \
        "error" \
        "acyclic-deps" \
        "${path:-$action}" \
        "self-loop detected: $from_id requires itself"
      sdd_count_error
    fi

    printf '%s\t%s\n' "$from_id" "$to_id" >> "$EDGES_FILE"
  done < <(sdd_fm_list "$action" '.requires')
done < <(sdd_find_actions "$SCOPE")

# No edges → trivially acyclic.
if [ ! -s "$EDGES_FILE" ]; then
  sdd_exit_with_counters
fi

# Cycle detection via tsort. BSD tsort reports cycles to stderr as:
#   tsort: cycle in data
#   tsort: <member1>
#   tsort: <member2>
tsort "$EDGES_FILE" >/dev/null 2>"$STDERR_FILE" || true

if grep -q "cycle in data" "$STDERR_FILE"; then
  cycle_members=$(
    grep -E "^tsort: " "$STDERR_FILE" \
      | grep -v "cycle in data" \
      | sed 's/^tsort:[[:space:]]*//' \
      | paste -sd, -
  )
  for member in $(printf '%s' "$cycle_members" | tr ',' '\n'); do
    [ -z "$member" ] && continue
    path="$(sdd_resolve_id "$member")"
    sdd_finding \
      "error" \
      "acyclic-deps" \
      "${path:-$member}" \
      "cycle in requires graph: $member participates in cycle with: $cycle_members"
    sdd_count_error
  done
fi

sdd_exit_with_counters
