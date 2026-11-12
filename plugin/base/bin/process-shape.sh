#!/usr/bin/env bash
# .inspire/bin/process-shape.sh
#
# Rule: a process states what starts it, which actions it runs, and a domain it
# affects that those actions can reach (adr-kb-structure D7).
#
#   TRIGGER  — `## Trigger` holds something. A process with no trigger never runs.
#   REQUIRES — `## Requires` links at least one action. A process with no action
#              does nothing.
#   AFFECTS  — every entity `## Affects` links is touched by one of the actions in
#              `## Requires` (their `## Entities` section). A process cannot
#              change what none of its actions writes.
#   ID       — `id:` is `{scope}.{process}`: two segments, its scope `global`, a
#              module or a face.
#
# Severity: lifecycle-progressive by the process's own `lifecycle:`.
#
# Usage:
#   .inspire/bin/process-shape.sh
#   .inspire/bin/process-shape.sh inspire_kb/01_spec/_processes

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_link-reads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="$(sdd_scope_intersect "${1:-}" "$SDD_SPEC_ROOT")"
[ -n "$SCOPE" ] || exit 0

emit() {
  sdd_finding "$1" "process-shape" "$2" "$3"
  sdd_count_by_severity "$1"
}

declared_ids() {
  sdd_section_link_ids "$1" "$2" \
    | while IFS= read -r l; do
        l="${l%%#*}"; l="${l%\\}"
        printf '%s\n' "${l//./::}"
      done | sort -u
}

sdd_build_id_index "$SDD_SPEC_ROOT"
sdd_link_index
trap 'rm -f "${SDD_ID_INDEX_FILE:-}" "${SDD_LINK_INDEX_FILE:-}" "${SDD_ENTITY_INDEX_FILE:-}"' EXIT

while IFS= read -r p; do
  [ -n "$p" ] || continue
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$p" '.lifecycle')")"

  id="$(sdd_fm_value "$p" '.id')"
  case "$id" in
    "") emit "$sev" "$p" "process carries no id: — write id: {scope}.{process} (scope: global, a module or a face)" ;;
    *.*.*|.*|*.) emit "$sev" "$p" "process id '$id' is not {scope}.{process}" ;;
    *.*) ;;
    *) emit "$sev" "$p" "process id '$id' is not {scope}.{process}" ;;
  esac

  if [ -z "$(sdd_body_section "$p" "Trigger" | grep -vE '^[[:space:]]*$|^<!--')" ]; then
    emit "$sev" "$p" "process has no trigger: '## Trigger' says what starts it (a schedule, an event, start-up, another process)"
  fi

  required="$(declared_ids "$p" "Requires" | grep -E '^[A-Za-z0-9_-]+::[A-Za-z0-9_-]+::[A-Za-z0-9_-]+$')"
  if [ -z "$required" ]; then
    emit "$sev" "$p" "process runs no action: '## Requires' links the actions it calls"
    continue
  fi

  touched=""
  while IFS= read -r a; do
    f="$(sdd_resolve_id "$a")"
    [ -n "$f" ] || continue
    touched="$touched
$(sdd_entities_touched "$f" | cut -f1 | sed 's/\./::/g' | sort -u)"
  done <<< "$required"

  while IFS= read -r e; do
    [ -n "$e" ] || continue
    case "$e" in *::*::*) continue ;; *::*) ;; *) continue ;; esac
    printf '%s\n' "$touched" | grep -qxF "$e" && continue
    emit "$sev" "$p" "process affects $e, which none of its required actions touches"
  done < <(declared_ids "$p" "Affects")
done < <(sdd_find_processes "$SCOPE")

sdd_exit_with_counters
