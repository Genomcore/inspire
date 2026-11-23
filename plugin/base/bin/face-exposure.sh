#!/usr/bin/env bash
# .inspire/bin/face-exposure.sh
#
# Rule: a screen depends only on actions its face's bundles expose
# (adr-kb-structure D6).
#
# A screen's face is the first segment of its id (`{face}.{slug}`, D5). That face's
# `{face}.face.md` lists the bundles it uses (`bundles: [api]`), and each
# `{bundle}.bundle.md` lists its actions under `## Actions` — a whole module
# (`[orders](../../_modules/orders/orders.module.md)`) or one action
# (`[orders::order::close](...)`). Every action a screen
# binds in its `## Bindings` (a `Data` or `Dispatches` row) must be one of them, and
# so must every action a face's shell binds and every action its store loads.
#
# Severity: lifecycle-progressive by the screen's own `lifecycle:`. A face that
# lists no bundles while its screens bind actions is one warning on the face: the
# exposure is undeclared, not wrong.
#
# Ownership: whether an action link resolves is links-resolve's rule, and
# whether the screen's face exists is screen-coherence's. This rule reads only
# links that already look like action ids.
#
# Usage:
#   .inspire/bin/face-exposure.sh
#   .inspire/bin/face-exposure.sh inspire_kb/01_spec/_faces/portal

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_link-reads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="$(sdd_scope_intersect "${1:-}" "$SDD_SPEC_ROOT")"
[ -n "$SCOPE" ] || exit 0

emit() {
  sdd_finding "$1" "face-exposure" "$2" "$3"
  sdd_count_by_severity "$1"
}

# Every link in a file's `## <section>`, as the id of the file it names, dots folded
# to `::` so `orders.order.close` and `orders::order::close` agree.
links_in() {
  sdd_section_link_ids "$1" "$2" \
    | while IFS= read -r l; do
        printf '%s\n' "${l//./::}"
      done
}

# face id → its bundles' exposure, one entry per line: `module` or `m::e::a`.
FACE_FILES="$(mktemp -t sdd-face-files.XXXXXX)"
trap 'rm -f "$FACE_FILES"' EXIT
while IFS= read -r f; do
  [ -n "$f" ] && printf '%s\t%s\n' "$(sdd_artifact_id "$f")" "$f" >> "$FACE_FILES"
done < <(sdd_find_faces "$SDD_SPEC_ROOT")

bundle_file() {
  local f
  while IFS= read -r f; do
    [ "$(sdd_artifact_id "$f")" = "$1" ] && { printf '%s\n' "$f"; return 0; }
  done < <(sdd_find_bundles "$SDD_SPEC_ROOT")
}

exposure_of_face() {
  local face_file="$1" b bf
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    bf="$(bundle_file "$b")"
    [ -n "$bf" ] && links_in "$bf" "Actions"
  done < <(sdd_fm_list "$face_file" '.bundles')
}

WARNED_FACES=""
while IFS= read -r screen; do
  [ -n "$screen" ] || continue
  id="$(sdd_fm_value "$screen" '.id')"
  face="${id%%.*}"
  [ -n "$face" ] && [ "$face" != "$id" ] || continue
  face_file="$(awk -F'\t' -v k="$face" '$1 == k { print $2; exit }' "$FACE_FILES")"
  [ -n "$face_file" ] || continue

  actions="$( { links_in "$screen" "Bindings"; } | grep -E '^[A-Za-z0-9_-]+::[A-Za-z0-9_-]+::[A-Za-z0-9_-]+$' | sort -u)"
  [ -n "$actions" ] || continue

  if [ -z "$(sdd_fm_list "$face_file" '.bundles')" ]; then
    case " $WARNED_FACES " in
      *" $face "*) ;;
      *) WARNED_FACES="$WARNED_FACES $face"
         emit "warning" "$face_file" "face '$face' lists no bundles: while its screens bind actions — declare which bundles expose them (bundles: [...])" ;;
    esac
    continue
  fi

  sev="$(sdd_progressive_severity "$(sdd_fm_value "$screen" '.lifecycle')")"
  exposure="$(exposure_of_face "$face_file" | sort -u)"
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    module="${a%%::*}"
    printf '%s\n' "$exposure" | grep -qxF -e "$a" -e "$module" && continue
    emit "$sev" "$screen" "binds action $a, which no bundle of face '$face' exposes — add it (or its module) to one of the face's bundles, or the face to a bundle that has it"
  done <<< "$actions"
done < <(sdd_find_screens "$SCOPE")

check_face_actions() {
  local file="$1" face="$2" sev="$3" section="$4" verb="$5" face_file actions exposure a module
  face_file="$(awk -F'\t' -v k="$face" '$1 == k { print $2; exit }' "$FACE_FILES")"
  [ -n "$face_file" ] || return 0
  actions="$(links_in "$file" "$section" | grep -E '^[A-Za-z0-9_-]+::[A-Za-z0-9_-]+::[A-Za-z0-9_-]+$' | sort -u)"
  [ -n "$actions" ] || return 0
  [ -n "$(sdd_fm_list "$face_file" '.bundles')" ] || return 0
  exposure="$(exposure_of_face "$face_file" | sort -u)"
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    module="${a%%::*}"
    printf '%s\n' "$exposure" | grep -qxF -e "$a" -e "$module" && continue
    emit "$sev" "$file" "$verb $a, which no bundle of face '$face' exposes — add it (or its module) to one of the face's bundles, or the face to a bundle that has it"
  done <<< "$actions"
}

while IFS= read -r store; do
  [ -n "$store" ] || continue
  check_face_actions "$store" "$(sdd_artifact_id "$store")" \
    "$(sdd_progressive_severity "$(sdd_fm_value "$store" '.lifecycle')")" "Server keys" "loads"
done < <(sdd_find_stores "$SCOPE")

while IFS= read -r layout; do
  [ -n "$layout" ] || continue
  sdd_has_section "$layout" "Bindings" || continue
  faces="$(sdd_fm_list "$layout" '.faces')"
  [ -n "$faces" ] || faces="$(cut -f1 "$FACE_FILES")"
  [ "$(printf '%s\n' "$faces" | grep -c .)" = 1 ] || continue
  case "$(sdd_catalog_state "$layout")" in
    implemented) sev="$(sdd_progressive_severity stable)" ;;
    to-extract)  sev="$(sdd_progressive_severity accepted)" ;;
    *)           sev="$(sdd_progressive_severity draft)" ;;
  esac
  check_face_actions "$layout" "$faces" "$sev" "Bindings" "binds action"
done < <(sdd_find_catalog "$SCOPE" layouts)

sdd_exit_with_counters
