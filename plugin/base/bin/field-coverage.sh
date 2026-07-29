#!/usr/bin/env bash
# .claude/bin/field-coverage.sh
#
# Rule: every field declared in an entity document's `## Fields` table must
# be touched by ≥1 action descriptor (read or write). A declared field that
# no action touches is a "field-uncovered" — the entity doc prescribes
# shape ahead of need, or an action declaration was removed without
# reconciling.
#
# This is the entity-doc inverse of `action-fields-in-entity` and a
# coverage check stricter than `entity-coherence`'s `field-orphan-write`:
#   - field-orphan-write (entity-coherence): some action writes the field,
#     but no action reads it (writing for no-one across actions).
#   - field-uncovered (this rule): the entity doc declares the field, but
#     no action touches it at all (entity → action coverage).
#
# Severity: lifecycle-progressive.
#   - entity at lifecycle: draft     → warning
#   - entity at lifecycle: accepted+ → error
#
# Usage:
#   .claude/bin/field-coverage.sh                  # scan whole tree
#   .claude/bin/field-coverage.sh .inspire_kb/04_domain/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

# Build a flat table of every (entity_id, field) touched by any action.
# entity_id<TAB>field
touches="$(mktemp -t sdd-touches.XXXXXX)"
trap 'rm -f "$touches"' EXIT

while IFS= read -r action; do
  [ -z "$action" ] && continue
  sdd_entities_touched "$action" \
    | sdd_expand_whole_reads \
    | awk -F'\t' '{ print $1 "\t" $2 }'
done < <(sdd_find_actions "$SCOPE") | sort -u >> "$touches"

# Iterate every entity document. For each declared field, check whether
# any action touches it.
while IFS= read -r entity; do
  [ -z "$entity" ] && continue
  entity_id="$(sdd_fm_value "$entity" '.id')"
  # Entity id may use dotted form (auth.user) in frontmatter; the
  # `## Entities` h3 headers use colon form (auth::user). Normalise to
  # the colon form used by sdd_entities_touched.
  rid_colon="${entity_id//./::}"

  # Externally-populated entities have no SDD writer and may be returned
  # whole by reader actions, so per-field coverage is not a meaningful
  # check. Skip them entirely.
  population="$(sdd_fm_value "$entity" '.population')"
  if [ "$population" = "external" ]; then
    continue
  fi

  lifecycle="$(sdd_fm_value "$entity" '.lifecycle')"
  severity="$(sdd_progressive_severity "$lifecycle")"

  while IFS= read -r field; do
    [ -z "$field" ] && continue
    # Check the touches table for any row matching (rid, field).
    if ! awk -F'\t' -v r="$rid_colon" -v f="$field" \
         '$1==r && $2==f { found=1; exit } END { exit !found }' "$touches"; then
      sdd_finding "$severity" "field-coverage" "$entity" \
        "field-uncovered: $rid_colon.$field is declared in '## Fields' but no action declares a touch on it"
      sdd_count_by_severity "$severity"
    fi
  done < <(sdd_entity_fields "$entity")
done < <(sdd_find_entities "$SCOPE")

sdd_exit_with_counters
