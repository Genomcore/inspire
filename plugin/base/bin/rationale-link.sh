#!/usr/bin/env bash
# .inspire/bin/rationale-link.sh
#
# Rule: every object must back-source its design decisions to upstream
# PDD or ADR documents via ≥1 link in the rationale-bearing section(s).
# Per D4 (prosaic back-sourcing): links weave inline into the prose that
# makes the claim; this rule enforces that ≥1 link is present.
#
# Rationale-bearing sections by object type:
#   - Entity document: ## Rationale
#   - Action descriptor: ## Purpose OR ## Behavior (either is acceptable —
#                        prosaic back-sourcing can land in either section).
#
# A Markdown link (`[text](path)`) counts; this rule does not verify resolution
# (that is `links-resolve`'s job).
#
# Severity: lifecycle-progressive.
#   - object at lifecycle: draft or superseded → warning
#   - object at lifecycle: accepted or stable  → error
#
# Usage:
#   .inspire/bin/rationale-link.sh                  # scan whole tree
#   .inspire/bin/rationale-link.sh inspire_kb/01_spec/_modules/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_link-reads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

# Returns 0 if the file's named section contains ≥1 link.
section_has_link() {
  [ -n "$(sdd_section_links "$1" "$2")" ]
}

while IFS= read -r action; do
  [ -z "$action" ] && continue
  lifecycle="$(sdd_fm_value "$action" '.lifecycle')"
  severity="$(sdd_progressive_severity "$lifecycle")"

  # Action: accept a link in either Purpose or Behavior.
  if ! section_has_link "$action" "Purpose" \
     && ! section_has_link "$action" "Behavior"; then
    sdd_finding "$severity" "rationale-link" "$action" \
      "action descriptor has no link in '## Purpose' or '## Behavior' (back-source to PDD/ADR is required for design discipline)"
    sdd_count_by_severity "$severity"
  fi
done < <(sdd_find_actions "$SCOPE")

while IFS= read -r entity; do
  [ -z "$entity" ] && continue
  lifecycle="$(sdd_fm_value "$entity" '.lifecycle')"
  severity="$(sdd_progressive_severity "$lifecycle")"

  if ! section_has_link "$entity" "Rationale"; then
    sdd_finding "$severity" "rationale-link" "$entity" \
      "entity document has no link in '## Rationale' (back-source to PDD/ADR is required for design discipline)"
    sdd_count_by_severity "$severity"
  fi
done < <(sdd_find_entities "$SCOPE")

sdd_exit_with_counters
