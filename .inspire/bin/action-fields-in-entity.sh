#!/usr/bin/env bash
# .claude/bin/action-fields-in-entity.sh
#
# Rule: every field declared in an action's `## Entities` per-entity
# field-touch table must appear in the touched entity document's `## Fields`
# table. This catches actions that reference fields the entity doc has not
# yet declared — the consolidation step is supposed to keep these in sync,
# so a drift means consolidation was skipped or the entity doc was edited
# out from under the action.
#
# Distinct from `entity-coherence`'s `field-unsourced`:
#   - field-unsourced (entity-coherence): action reads a field that no
#     other action writes (read/write coherence across actions).
#   - action-fields-in-entity (this rule): action touches a field that the
#     entity document's Fields table does not declare (action ↔ entity
#     doc shape coherence).
#
# Severity: error (coherence blocker, applies from draft+).
#
# Usage:
#   .claude/bin/action-fields-in-entity.sh                  # scan whole tree
#   .claude/bin/action-fields-in-entity.sh .inspire_kb/04_domain/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

while IFS= read -r action; do
  [ -z "$action" ] && continue
  action_id="$(sdd_fm_value "$action" '.id')"

  # Group declared fields per entity id (one action may declare touches
  # on several entities, with several fields each).
  declarations="$(sdd_entities_touched "$action" | awk -F'\t' '{ print $1 "\t" $2 }' | sort -u)"
  [ -z "$declarations" ] && continue

  # Cache entity doc field lists per entity id.
  prev_rid=""
  fields_cache=""
  entity_missing=""

  while IFS=$'\t' read -r rid field; do
    [ -z "$rid" ] && continue
    if [ "$rid" != "$prev_rid" ]; then
      prev_rid="$rid"
      entity_file="$(sdd_resolve_entity_id "$rid" 2>/dev/null || true)"
      if [ -z "$entity_file" ]; then
        entity_missing="1"
        fields_cache=""
        sdd_finding "error" "action-fields-in-entity" "$action" \
          "action ${action_id:-?} touches entity $rid but no entity document found at expected path"
        sdd_count_error
      else
        entity_missing=""
        fields_cache="$(sdd_entity_fields "$entity_file")"
      fi
    fi
    [ -n "$entity_missing" ] && continue

    # Look for the field in the entity doc's Fields table.
    if ! printf '%s\n' "$fields_cache" | awk -v f="$field" '$0 == f { found = 1; exit } END { exit !found }'; then
      sdd_finding "error" "action-fields-in-entity" "$action" \
        "action ${action_id:-?} touches field '$field' on $rid but the entity document's '## Fields' table does not declare it"
      sdd_count_error
    fi
  done <<< "$declarations"
done < <(sdd_find_actions "$SCOPE")

sdd_exit_with_counters
