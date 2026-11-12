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
# binds in its `## Bindings` (a `Data` or `Dispatches` row) must be one of them.
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

# Every link in a file's `## <section>`, as the id it refers to (a wikilink's declared
# id, a Markdown link's target file id), dots folded to `::` so `orders.order.close`
# and `orders::order::close` agree.
links_in() {
  sdd_section_link_ids "$1" "$2" \
    | while IFS= read -r l; do
        l="${l%%#*}"; l="${l%\\}"
        printf '%s\n' "${l//./::}"
      done
}

# face id → its bundles' exposure, one entry per line: `module` or `m::e::a`.
FACE_FILES="$(mktemp -t sdd-face-files.XXXXXX)"
sdd_link_index
trap 'rm -f "$FACE_FILES" "${SDD_LINK_INDEX_FILE:-}" "${SDD_ENTITY_INDEX_FILE:-}"' EXIT
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

sdd_exit_with_counters
