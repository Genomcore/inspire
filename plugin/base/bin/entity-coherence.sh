#!/usr/bin/env bash
# .claude/bin/entity-coherence.sh
#
# Per-field rule (not per-entity) with three findings:
#   - field-conflict     (error)   — same Field on same Entity declared
#                                    with different Types across actions
#   - field-unsourced    (error)   — Field is read by someone but no action
#                                    declares it with Touch=written on the
#                                    same entity
#   - field-orphan-write (warning) — Field is written by someone but no
#                                    action declares it with Touch=read on
#                                    the same entity. "Writing for no-one."
#
# Source: each action's `## Entities` section, parsed by
# `sdd_entities_touched` in _lib.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

# Build a flat declarations table:
#   entity<TAB>field<TAB>touch<TAB>type<TAB>action_file
decls="$(mktemp -t sdd-decls.XXXXXX)"
trap 'rm -f "$decls"' EXIT

while IFS= read -r action; do
  [ -z "$action" ] && continue
  # Use awk -F'\t' to safely extract fields — IFS=$'\t' in bash read collapses
  # consecutive tabs (empty fields), which breaks synthetic rows from sdd_expand_whole_reads.
  awk -F'\t' -v action="$action" '
    $1 != "" { printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, action }
  ' < <(sdd_entities_touched "$action" | sdd_expand_whole_reads) >> "$decls"
done < <(sdd_find_actions "$SCOPE")

# Returns 1 if the given (entity, field, touch) combination exists in decls.
field_has() {
  local rid="$1" field="$2" touch="$3"
  awk -F'\t' -v r="$rid" -v f="$field" -v t="$touch" \
    '$1==r && $2==f && $3==t { found=1; exit } END { exit !found }' "$decls"
}

# Check 1 — field-conflict: same field on same entity with differing types
while IFS=$'\t' read -r rid field; do
  types="$(awk -F'\t' -v r="$rid" -v f="$field" '$1==r && $2==f { print $4 }' "$decls" | sort -u)"
  count="$(printf '%s\n' "$types" | grep -c .)"
  if [ "$count" -gt 1 ]; then
    joined="$(printf '%s\n' "$types" | tr '\n' '/' | sed 's|/$||')"
    sdd_finding "error" "entity-coherence" "$rid" \
      "field-conflict: $rid.$field has differing types across actions: $joined"
    sdd_count_error
  fi
done < <(cut -f1,2 "$decls" | sort -u)

# Check 2 — field-unsourced (error): read but never written
# Check 3 — field-orphan-write (warning): written but never read
while IFS=$'\t' read -r rid field; do
  if field_has "$rid" "$field" "read" && ! field_has "$rid" "$field" "written"; then
    population="$(sdd_entity_population "$rid")"
    if [ "$population" != "external" ]; then
      sdd_finding "error" "entity-coherence" "$rid" \
        "field-unsourced: $rid.$field is read but no action declares Touch=written"
      sdd_count_error
    fi
  fi
  if field_has "$rid" "$field" "written" && ! field_has "$rid" "$field" "read"; then
    sdd_finding "warning" "entity-coherence" "$rid" \
      "field-orphan-write: $rid.$field is written but no action declares Touch=read (writing for no-one)"
    sdd_count_warning
  fi
done < <(cut -f1,2 "$decls" | sort -u)

# Check 4 — write-on-external: any write touch on a population:external entity
# is a structural contradiction (external entities have no SDD writers).
while IFS=$'\t' read -r rid field action_file; do
  population="$(sdd_entity_population "$rid")"
  if [ "$population" = "external" ]; then
    sdd_finding "error" "entity-coherence" "$rid" \
      "write-on-external: $rid.$field is written by $action_file but entity is population:external"
    sdd_count_error
  fi
done < <(awk -F'\t' '$3=="written" { print $1 "\t" $2 "\t" $5 }' "$decls" | sort -u)

sdd_exit_with_counters
