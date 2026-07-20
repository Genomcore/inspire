#!/usr/bin/env bash
# .claude/bin/touched-entity-lifecycle.sh
#
# Rule: every action at lifecycle: stable must touch only entities whose
# own lifecycle is >= accepted. Promotion gating is one-directional:
# entities promote independently of touching actions, but stabilizing an
# action requires the entities it touches to be at least accepted.
#
# The touch graph (action ↔ entity) is bipartite by construction —
# cross-object cycles cannot form, so the gate is a simple per-action
# scan rather than a transitive walk.
#
# Severity: error (blocker).
#
# Usage:
#   .claude/bin/touched-entity-lifecycle.sh                  # scan whole tree
#   .claude/bin/touched-entity-lifecycle.sh spec/sdd/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

# Lifecycle ordering: draft < accepted < stable < superseded.
# A touched entity passes the gate iff it is at "accepted" or "stable"
# (or "superseded" — terminal, treated as ≥ accepted by historical fiat).
# Anything else (empty / "draft" / unknown) fails the gate.
lifecycle_ge_accepted() {
  case "$1" in
    accepted|stable|superseded) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r action; do
  [ -z "$action" ] && continue
  lifecycle="$(sdd_fm_value "$action" '.lifecycle')"
  [ "$lifecycle" != "stable" ] && continue

  action_id="$(sdd_fm_value "$action" '.id')"

  # Deduplicate touched entity ids (one action may declare multiple
  # field rows per entity).
  while IFS= read -r rid; do
    [ -z "$rid" ] && continue

    target_file="$(sdd_resolve_entity_id "$rid" 2>/dev/null || true)"
    if [ -z "$target_file" ]; then
      sdd_finding "error" "touched-entity-lifecycle" "$action" \
        "stable action $action_id touches entity $rid but no entity document found at expected path"
      sdd_count_error
      continue
    fi

    target_lifecycle="$(sdd_fm_value "$target_file" '.lifecycle')"
    if ! lifecycle_ge_accepted "$target_lifecycle"; then
      sdd_finding "error" "touched-entity-lifecycle" "$action" \
        "stable action $action_id touches entity $rid which is at lifecycle: ${target_lifecycle:-<unset>} (must be at least accepted)"
      sdd_count_error
    fi
  done < <(sdd_entities_touched "$action" | cut -f1 | sort -u)
done < <(sdd_find_actions "$SCOPE")

sdd_exit_with_counters
