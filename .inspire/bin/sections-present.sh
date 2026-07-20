#!/usr/bin/env bash
# .claude/bin/sections-present.sh
#
# Rule: every object descriptor must declare its mandatory body sections,
# and each section's body must be non-empty (a header alone is insufficient).
#
# Section sets per object type (from SKILL.md format spec):
#
#   Action descriptor (3-segment leaf filename):
#     ## Purpose
#     ## Inputs
#     ## Outputs
#     ## Entities
#     ## Behavior
#     ## Errors
#
#   Entity document (2-segment leaf filename):
#     ## Purpose
#     ## Rationale
#     ## Invariants
#     ## Fields
#
# A section is "present" when an H2 header with the exact name exists.
# A section is "non-empty" when at least one line of body content (other than
# whitespace and section-only structural noise) appears under it.
#
# `## Touched by` (entity) and `## Errors` for actions with literally no
# error cases (`- \`none\`` is a valid one-line body) are both covered by
# this rule because the body merely needs to be non-empty — operators can
# document "None" explicitly.
#
# Severity: error (coherence blocker, applies from draft+).
#
# Usage:
#   .claude/bin/sections-present.sh                  # scan whole tree
#   .claude/bin/sections-present.sh .inspire_kb/04_domain/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

ACTION_SECTIONS=("Purpose" "Inputs" "Outputs" "Entities" "Behavior" "Errors")
ENTITY_SECTIONS=("Purpose" "Rationale" "Invariants" "Fields")

# Print 1 if the section body has at least one non-blank, non-header content
# line; print 0 otherwise. Pipes the body to a small awk that strips
# whitespace-only lines and HTML comments.
section_has_content() {
  local file="$1" header="$2"
  sdd_body_section "$file" "$header" \
    | awk '
        # Strip whitespace.
        { gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
        # Skip blank lines.
        /^$/ { next }
        # Skip HTML comments-only lines.
        /^<!--.*-->$/ { next }
        { found = 1; exit }
        END { if (found) print 1; else print 0 }
      '
}

check_action() {
  local file="$1"
  local missing=() empty=()
  local section
  for section in "${ACTION_SECTIONS[@]}"; do
    # Section header presence: re-extract from body looking for ^## $section$.
    if ! awk -v hdr="## $section" '
          /^---$/ { fm = !fm; next }
          fm { next }
          $0 == hdr { found = 1; exit }
          END { exit !found }
        ' "$file"; then
      missing+=("$section")
      continue
    fi
    local has_content
    has_content="$(section_has_content "$file" "$section")"
    if [ "$has_content" != "1" ]; then
      empty+=("$section")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    sdd_finding "error" "sections-present" "$file" \
      "action descriptor missing required section(s): $(IFS=,; echo "${missing[*]}")"
    sdd_count_error
  fi
  if [ ${#empty[@]} -gt 0 ]; then
    sdd_finding "error" "sections-present" "$file" \
      "action descriptor has empty section(s) (header present but no body content): $(IFS=,; echo "${empty[*]}")"
    sdd_count_error
  fi
}

check_entity() {
  local file="$1"
  local missing=() empty=()
  local section
  for section in "${ENTITY_SECTIONS[@]}"; do
    if ! awk -v hdr="## $section" '
          /^---$/ { fm = !fm; next }
          fm { next }
          $0 == hdr { found = 1; exit }
          END { exit !found }
        ' "$file"; then
      missing+=("$section")
      continue
    fi
    local has_content
    has_content="$(section_has_content "$file" "$section")"
    if [ "$has_content" != "1" ]; then
      empty+=("$section")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    sdd_finding "error" "sections-present" "$file" \
      "entity document missing required section(s): $(IFS=,; echo "${missing[*]}")"
    sdd_count_error
  fi
  if [ ${#empty[@]} -gt 0 ]; then
    sdd_finding "error" "sections-present" "$file" \
      "entity document has empty section(s) (header present but no body content): $(IFS=,; echo "${empty[*]}")"
    sdd_count_error
  fi
}

while IFS= read -r action; do
  [ -z "$action" ] && continue
  check_action "$action"
done < <(sdd_find_actions "$SCOPE")

while IFS= read -r entity; do
  [ -z "$entity" ] && continue
  check_entity "$entity"
done < <(sdd_find_entities "$SCOPE")

sdd_exit_with_counters
