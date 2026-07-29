#!/usr/bin/env bash
# .claude/bin/frontmatter-mechanics.sh
#
# Mechanical-blocker bundle (always enforced, any lifecycle). Groups three
# small frontmatter checks into one pass over the SDD tree:
#
#   1. lifecycle-valid    — `lifecycle:` frontmatter field is present and
#                           one of {draft, accepted, stable, superseded}.
#   2. requires-resolves  — every entry in `requires:` resolves to an existing
#                           action descriptor under $SDD_SPEC_ROOT.
#   3. superseded-by-resolves — when `superseded_by:` is set (non-empty, not
#                           null), it resolves to an existing action descriptor.
#
# All findings are severity: error. These checks gate every commit regardless
# of the primitive's lifecycle (mechanical correctness). Lifecycle-progressive
# rules live in their own scripts.
#
# Severity: error.
#
# Usage:
#   .claude/bin/frontmatter-mechanics.sh                  # scan whole tree
#   .claude/bin/frontmatter-mechanics.sh .inspire_kb/04_domain/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

sdd_build_id_index "$SCOPE"
trap 'rm -f "${SDD_ID_INDEX_FILE:-}"' EXIT

# Valid lifecycle enum values.
is_valid_lifecycle() {
  case "$1" in
    draft|accepted|stable|superseded) return 0 ;;
    *) return 1 ;;
  esac
}

# Iterate every object (actions + entities) and run the three checks.
check_file() {
  local file="$1"
  local kind="$2"   # "action" or "entity"

  # ---------- Check 1: lifecycle-valid ----------
  local lifecycle
  lifecycle="$(sdd_fm_value "$file" '.lifecycle')"
  if [ -z "$lifecycle" ]; then
    sdd_finding "error" "lifecycle-valid" "$file" \
      "$kind missing required frontmatter field: lifecycle"
    sdd_count_error
  elif ! is_valid_lifecycle "$lifecycle"; then
    sdd_finding "error" "lifecycle-valid" "$file" \
      "$kind has invalid lifecycle value: '$lifecycle' (expected one of: draft, accepted, stable, superseded)"
    sdd_count_error
  fi

  # ---------- Check 2: requires-resolves ----------
  # Only action descriptors carry `requires:`. Entity documents do not.
  if [ "$kind" = "action" ]; then
    while IFS= read -r req; do
      [ -z "$req" ] && continue
      local to_id
      to_id="$(sdd_unwrap_wikilink "$req")"
      local target_file
      target_file="$(sdd_resolve_id "$to_id")"
      if [ -z "$target_file" ]; then
        sdd_finding "error" "requires-resolves" "$file" \
          "requires target does not resolve to an existing action descriptor: $to_id"
        sdd_count_error
      fi
    done < <(sdd_fm_list "$file" '.requires')
  fi

  # ---------- Check 3: superseded-by-resolves ----------
  local sb
  sb="$(sdd_fm_value "$file" '.superseded_by')"
  # yq returns empty string for null / missing. Skip when empty.
  if [ -n "$sb" ] && [ "$sb" != "null" ]; then
    local sb_id
    sb_id="$(sdd_unwrap_wikilink "$sb")"
    local sb_target
    sb_target="$(sdd_resolve_id "$sb_id")"
    if [ -z "$sb_target" ]; then
      sdd_finding "error" "superseded-by-resolves" "$file" \
        "superseded_by target does not resolve to an existing object: $sb_id"
      sdd_count_error
    fi
  fi
}

while IFS= read -r action; do
  [ -z "$action" ] && continue
  check_file "$action" "action"
done < <(sdd_find_actions "$SCOPE")

while IFS= read -r entity; do
  [ -z "$entity" ] && continue
  check_file "$entity" "entity"
done < <(sdd_find_entities "$SCOPE")

sdd_exit_with_counters
