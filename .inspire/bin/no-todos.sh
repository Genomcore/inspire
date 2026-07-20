#!/usr/bin/env bash
# .claude/bin/no-todos.sh
#
# Rule: SDD object bodies must not contain TODO or FIXME markers. Per D19
# (Addendum 2): files state present truth only. Outstanding work belongs in
# `.inspire_kb/06_tracker/tickets/`, not inline in the spec.
#
# Detects (case-sensitive, word-boundary): TODO, FIXME, XXX, HACK.
# Limited to body content — frontmatter is excluded so the rule does not
# trip on meta-comments in the YAML block.
#
# Severity: error (coherence blocker, applies from draft+).
#
# Usage:
#   .claude/bin/no-todos.sh                  # scan whole tree
#   .claude/bin/no-todos.sh .inspire_kb/04_specs/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

scan_file() {
  local file="$1"
  # awk extracts (line_number, marker) pairs from the body (frontmatter
  # skipped). Each output line is "linenum<TAB>marker". The while loop
  # reads results sequentially in the parent shell so finding counters
  # increment correctly (no subshell-from-pipe pitfall).
  local hits
  hits="$(awk '
    BEGIN { line = 0 }
    /^---$/ { fm = !fm; line++; next }
    { line++ }
    !fm {
      n = split($0, _ignored, "")  # noop
      if (match($0, /TODO|FIXME|XXX|HACK/)) {
        marker = substr($0, RSTART, RLENGTH)
        print line "\t" marker
      }
    }
  ' "$file")"

  [ -z "$hits" ] && return 0

  while IFS=$'\t' read -r ln marker; do
    [ -z "$ln" ] && continue
    sdd_finding "error" "no-todos" "$file" \
      "body contains $marker marker at line $ln (files state present truth only — move outstanding work to .inspire_kb/06_tracker/tickets/)"
    sdd_count_error
  done <<< "$hits"
}

while IFS= read -r action; do
  [ -z "$action" ] && continue
  scan_file "$action"
done < <(sdd_find_actions "$SCOPE")

while IFS= read -r entity; do
  [ -z "$entity" ] && continue
  scan_file "$entity"
done < <(sdd_find_entities "$SCOPE")

sdd_exit_with_counters
