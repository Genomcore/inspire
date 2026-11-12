#!/usr/bin/env bash
# .inspire/bin/stable-blockers.sh
#
# Rule: every action at lifecycle: stable must have all `requires` targets
# also at lifecycle: stable. Promotion is blocked otherwise.
#
# Severity: error.
#
# Usage:
#   .inspire/bin/stable-blockers.sh                  # scan whole tree
#   .inspire/bin/stable-blockers.sh inspire_kb/01_spec/_modules/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_link-reads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

sdd_build_id_index "$SDD_SPEC_ROOT"
trap 'rm -f "${SDD_ID_INDEX_FILE:-}"' EXIT

while IFS= read -r action; do
  [ -z "$action" ] && continue
  lifecycle="$(sdd_fm_value "$action" '.lifecycle')"
  [ "$lifecycle" != "stable" ] && continue

  while IFS=$'\t' read -r form target to_id path; do
    if [ "$form" != bare ]; then target_file=""; [ -f "$path" ] && target_file="$path"; to_id="${to_id:-$target}"
    else target_file="$(sdd_resolve_id "$to_id")"; fi
    if [ -z "$target_file" ]; then
      sdd_finding "error" "stable-blockers" "$action" "requires target not found: $to_id"
      sdd_count_error
      continue
    fi

    target_lifecycle="$(sdd_fm_value "$target_file" '.lifecycle')"
    if [ "$target_lifecycle" != "stable" ]; then
      sdd_finding "error" "stable-blockers" "$action" "stable action requires $to_id which is at lifecycle: $target_lifecycle"
      sdd_count_error
    fi
  done < <(sdd_fm_link_refs "$action" requires)
done < <(sdd_find_actions "$SCOPE")

sdd_exit_with_counters
