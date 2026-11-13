#!/usr/bin/env bash
# .inspire/bin/spec-identity.sh
#
# Rule: every specification artifact has an id it can be found by, and only one
# artifact has it (adr-kb-structure D2, D3, D8).
#
#   RESERVED  — a user-chosen id never starts with `_`: a leading `_` is INSPIRE
#               structure (`_modules/`, `_faces/` …). Error.
#   UNIQUE    — two artifacts of one type never share an id within the scope D3
#               names: the project for modules, ADRs, bundles, faces, stores,
#               processes and catalog entries; the module for features.
#               Entities, actions and screens are checked by the rules that own
#               them. Error.
#   TYPE      — a frontmatter `type:` (or a `kind:` that names a type) agrees with
#               the typed extension. Error.
#   FACES AND BUNDLES, as a set (what the surface roster used to check):
#               two faces never share a shell; a face's `bundles:` names bundles
#               that exist, and its `shell_layout:` a layout that exists; a
#               bundle declares its `package:` (warning — the Factory cannot plan
#               its mount test without one).
#
# Scope: `$1 ∩ 01_spec` for what is reported; the indexes are spec-wide, because a
# duplicate is not local.
#
# Usage:
#   .inspire/bin/spec-identity.sh
#   .inspire/bin/spec-identity.sh inspire_kb/01_spec/_faces

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="$(sdd_scope_intersect "${1:-}" "$SDD_SPEC_ROOT")"
[ -n "$SCOPE" ] || exit 0
[ -d "$SDD_SPEC_ROOT" ] || exit 0

emit() {
  sdd_finding "$1" "spec-identity" "$2" "$3"
  sdd_count_by_severity "$1"
}

in_scope() {
  case "$(sdd_scope_norm "$1")" in
    "$(sdd_scope_norm "$SCOPE")" | "$(sdd_scope_norm "$SCOPE")"/*) return 0 ;;
  esac
  return 1
}

INDEX="$(mktemp -t sdd-spec-identity.XXXXXX)"
trap 'rm -f "$INDEX"' EXIT

# kind <TAB> uniqueness key <TAB> id <TAB> path — one row per typed artifact.
TYPES="module feature entity action adr adr.rationale bundle face store screen process component layout pattern"
for t in $TYPES; do
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    id="$(sdd_artifact_id "$f")"
    case "$t" in
      feature)
        # Unique within its module: the module directory holding `_features/`.
        key="${f%/_features/*}" ;;
      *) key="project" ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$t" "$key" "$id" "$f" >> "$INDEX"
  done < <(sdd_find_typed "$SDD_SPEC_ROOT" "$t")
done

while IFS="$(printf '\t')" read -r kind key id file; do
  in_scope "$file" || continue

  base="${file##*/}"
  case "$id" in
    _*) emit "error" "$file" "id '$id' starts with '_', which is reserved for INSPIRE structure — rename it" ;;
    *) case "$base" in
         _*) emit "error" "$file" "file name '$base' starts with '_', which is reserved for navigation and INSPIRE structure" ;;
       esac ;;
  esac

  case "$kind" in
    entity|action|screen) ;;
    *)
      other="$(awk -F'\t' -v k="$kind" -v key="$key" -v id="$id" -v self="$file" \
        '$1 == k && $2 == key && $3 == id && $4 != self { print $4; exit }' "$INDEX")"
      [ -n "$other" ] && emit "error" "$file" "duplicate $kind id '$id': also declared by $other"
      ;;
  esac

  declared="$(sdd_fm_value "$file" '.type')"
  [ -n "$declared" ] && [ "$declared" != "null" ] || declared="$(sdd_fm_value "$file" '.kind')"
  case "$declared" in
    module-hub) declared="module" ;;
    rationale|adr-rationale) declared="adr.rationale" ;;
  esac
  case " $TYPES " in
    *" $declared "*)
      [ "$declared" = "$kind" ] || \
        emit "error" "$file" "frontmatter says this is a $declared, its extension says $kind — one of them is wrong" ;;
  esac
done < "$INDEX"

# Faces and bundles, as a set.
bundles="$(awk -F'\t' '$1 == "bundle" { print $3 }' "$INDEX")"
SHELLS="$(mktemp -t sdd-spec-shells.XXXXXX)"
trap 'rm -f "$INDEX" "$SHELLS"' EXIT
while IFS= read -r face; do
  [ -n "$face" ] || continue
  shell="$(sdd_fm_value "$face" '.shell')"
  [ -n "$shell" ] && [ "$shell" != "null" ] && printf '%s\t%s\n' "$shell" "$face" >> "$SHELLS"
done < <(sdd_find_faces "$SDD_SPEC_ROOT")

while IFS= read -r face; do
  [ -n "$face" ] || continue
  in_scope "$face" || continue
  shell="$(sdd_fm_value "$face" '.shell')"
  if [ -n "$shell" ] && [ "$shell" != "null" ]; then
    other="$(awk -F'\t' -v s="$shell" -v self="$face" '$1 == s && $2 != self { print $2; exit }' "$SHELLS")"
    [ -n "$other" ] && emit "error" "$face" "shell '$shell' is also the shell of $other — two faces cannot share a route prefix"
  fi
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    printf '%s\n' "$bundles" | grep -qxF "$b" || \
      emit "error" "$face" "face uses bundle '$b', which no {bundle}.bundle.md declares"
  done < <(sdd_fm_list "$face" '.bundles')
  shell_layout="$(sdd_fm_value "$face" '.shell_layout')"
  if [ -n "$shell_layout" ] && [ "$shell_layout" != "null" ]; then
    awk -F'\t' -v id="$shell_layout" '$1 == "layout" && $3 == id { f = 1 } END { exit !f }' "$INDEX" || \
      emit "error" "$face" "face names shell layout '$shell_layout', which no {layout}.layout.md declares"
  fi
done < <(sdd_find_faces "$SDD_SPEC_ROOT")

while IFS= read -r bundle; do
  [ -n "$bundle" ] || continue
  in_scope "$bundle" || continue
  pkg="$(sdd_fm_value "$bundle" '.package')"
  if [ -z "$pkg" ] || [ "$pkg" = "null" ]; then
    emit "warning" "$bundle" "bundle declares no package: — the package that exposes its actions is recorded nowhere"
  fi
done < <(sdd_find_bundles "$SDD_SPEC_ROOT")

sdd_exit_with_counters
