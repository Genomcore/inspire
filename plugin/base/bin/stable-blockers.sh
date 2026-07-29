#!/usr/bin/env bash
# .claude/bin/stable-blockers.sh
#
# Rule: every action at lifecycle: stable must have all `requires` targets
# also at lifecycle: stable. Promotion is blocked otherwise.
#
# Severity: error.
#
# Usage:
#   .claude/bin/stable-blockers.sh                  # scan whole tree
#   .claude/bin/stable-blockers.sh .inspire_kb/04_domain/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

sdd_build_id_index "$SCOPE"
trap 'rm -f "${SDD_ID_INDEX_FILE:-}"' EXIT

while IFS= read -r action; do
  [ -z "$action" ] && continue
  lifecycle="$(sdd_fm_value "$action" '.lifecycle')"
  [ "$lifecycle" != "stable" ] && continue

  while IFS= read -r req; do
    [ -z "$req" ] && continue
    to_id="$(sdd_unwrap_wikilink "$req")"

    target_file="$(sdd_resolve_id "$to_id")"
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
  done < <(sdd_fm_list "$action" '.requires')
done < <(sdd_find_actions "$SCOPE")

sdd_exit_with_counters
