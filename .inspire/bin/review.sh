#!/usr/bin/env bash
# .claude/bin/review.sh
#
# Composite review — orchestrates the rule scripts and aggregates findings.
# Run by skills (`/inspire_object review`, `/inspire_feature review`) and
# by the pre-PR hook.
#
# Findings from sub-scripts (JSON lines on stderr) pass through unchanged.
# Stdout receives a human-readable summary.
# Exit code: 0 if all rules pass with no errors; 1 if any error finding.
#
# Usage:
#   .claude/bin/review.sh                # scan whole tree
#   .claude/bin/review.sh .inspire_kb/04_domain/auth  # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127

SCOPE="${1:-$SDD_SPEC_ROOT}"

# Rule scripts to run, in order. The caller can override via the
# SDD_REVIEW_RULES env var (space-separated script names) to run a
# subset.
#
# Ordering: cheap mechanical blockers first, then coherence blockers,
# then lifecycle-progressive (warning-then-blocker). Within each tier
# order is arbitrary but stable.
DEFAULT_RULES="\
frontmatter-mechanics.sh \
acyclic-deps.sh \
sections-present.sh \
no-todos.sh \
action-fields-in-entity.sh \
entity-coherence.sh \
stable-blockers.sh \
touched-entity-lifecycle.sh \
field-coverage.sh \
rationale-wikilink.sh \
wikilinks-resolve.sh"
read -r -a RULES <<< "${SDD_REVIEW_RULES:-$DEFAULT_RULES}"

EXIT_CODE=0

for rule_script in "${RULES[@]}"; do
  rule_path="$SCRIPT_DIR/$rule_script"
  if [ ! -x "$rule_path" ]; then
    echo "warning: rule script not executable: $rule_path" >&2
    continue
  fi
  if ! "$rule_path" "$SCOPE"; then
    EXIT_CODE=1
  fi
done

# Human-readable summary on stdout.
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "review: PASS — no errors found in scope: $SCOPE"
else
  echo "review: FAIL — one or more rules emitted errors (see stderr findings)"
fi

exit "$EXIT_CODE"
