#!/usr/bin/env bash
# .claude/bin/rationale-wikilink.sh
#
# Rule: every object must back-source its design decisions to upstream
# PDD or ADR documents via ≥1 wikilink in the rationale-bearing section(s).
# Per D4 (prosaic back-sourcing): wikilinks weave inline into the prose that
# makes the claim; this rule enforces that ≥1 link is present.
#
# Rationale-bearing sections by object type:
#   - Entity document: ## Rationale
#   - Action descriptor: ## Purpose OR ## Behavior (either is acceptable —
#                        prosaic back-sourcing can land in either section).
#
# Wikilinks of the form `[[anything]]` count; this rule does not verify
# resolution (that is `wikilinks-resolve`'s job).
#
# Severity: lifecycle-progressive.
#   - object at lifecycle: draft     → warning
#   - object at lifecycle: accepted+ → error
#
# Usage:
#   .claude/bin/rationale-wikilink.sh                  # scan whole tree
#   .claude/bin/rationale-wikilink.sh .inspire_kb/04_specs/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

# Returns 0 if the file's named section contains ≥1 [[wikilink]].
section_has_wikilink() {
  local file="$1" header="$2"
  sdd_body_section "$file" "$header" \
    | grep -q '\[\[[^]]\+\]\]'
}

while IFS= read -r action; do
  [ -z "$action" ] && continue
  lifecycle="$(sdd_fm_value "$action" '.lifecycle')"
  severity="$(sdd_progressive_severity "$lifecycle")"

  # Action: accept a wikilink in either Purpose or Behavior.
  if ! section_has_wikilink "$action" "Purpose" \
     && ! section_has_wikilink "$action" "Behavior"; then
    sdd_finding "$severity" "rationale-wikilink" "$action" \
      "action descriptor has no wikilink in '## Purpose' or '## Behavior' (back-source to PDD/ADR is required for design discipline)"
    sdd_count_by_severity "$severity"
  fi
done < <(sdd_find_actions "$SCOPE")

while IFS= read -r entity; do
  [ -z "$entity" ] && continue
  lifecycle="$(sdd_fm_value "$entity" '.lifecycle')"
  severity="$(sdd_progressive_severity "$lifecycle")"

  if ! section_has_wikilink "$entity" "Rationale"; then
    sdd_finding "$severity" "rationale-wikilink" "$entity" \
      "entity document has no wikilink in '## Rationale' (back-source to PDD/ADR is required for design discipline)"
    sdd_count_by_severity "$severity"
  fi
done < <(sdd_find_entities "$SCOPE")

sdd_exit_with_counters
