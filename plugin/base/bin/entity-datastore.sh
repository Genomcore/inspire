#!/usr/bin/env bash
# .inspire/bin/entity-datastore.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_keyed-heads.sh"

sdd_require_tools || exit 127
sdd_init_counters
_sdd_entity_index

SCOPE="${1:-}"
RULE="entity-datastore"
STACK="$SDD_BOOTSTRAP_ROOT/stack.md"
TAB=$'\t'

ED_TMP="$(mktemp -t sdd-datastore.XXXXXX)"
trap 'rm -f "$ED_TMP" "${SDD_ENTITY_INDEX_FILE:-}"' EXIT

DATASTORES=""
DEFAULT=""
PROFILES=""
if [ -f "$STACK" ]; then
  DATASTORES="$(yq --front-matter=extract \
    '(.datastores // {}) | to_entries | .[] | .key + "\t" + (.value | tostring)' "$STACK" 2>/dev/null || true)"
  DEFAULT="$(sdd_fm_value "$STACK" '.default_datastore')"
  [ "$DEFAULT" = "null" ] && DEFAULT=""
  PROFILES="$(sdd_fm_list "$STACK" '.profiles')"
fi

COUNT=0
[ -n "$DATASTORES" ] && COUNT="$(printf '%s\n' "$DATASTORES" | grep -c .)"
if [ -z "$DEFAULT" ] && [ "$COUNT" -eq 1 ]; then
  DEFAULT="${DATASTORES%%"$TAB"*}"
fi

ed_stack_of() {
  printf '%s\n' "$DATASTORES" | awk -F'\t' -v id="$1" '$1 == id { print $2; exit }'
}

ed_declared() {
  [ -n "$DATASTORES" ] && printf '%s\n' "$DATASTORES" | awk -F'\t' -v id="$1" '$1 == id { f = 1 } END { exit !f }'
}

ed_named() {
  local value
  value="$(sdd_fm_value "$1" '.datastore')"
  [ "$value" = "null" ] && value=""
  printf '%s\n' "$value"
}

ed_embedded() {
  local value
  value="$(sdd_fm_value "$1" '.embedded_in')"
  [ "$value" = "null" ] && value=""
  printf '%s\n' "$value"
}

ed_own() {
  local named
  named="$(ed_named "$1")"
  if [ -n "$named" ]; then printf '%s\n' "$named"; else printf '%s\n' "$DEFAULT"; fi
}

ed_resolved() {
  local parent parent_file
  parent="$(ed_embedded "$1")"
  if [ -n "$parent" ] && parent_file="$(sdd_resolve_entity_id "$parent")" && [ "$parent_file" != "$1" ]; then
    ed_own "$parent_file"
  else
    ed_own "$1"
  fi
}

ed_has_persistence() {
  local skill
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    sdd_has_section "$skill" "Persistence" && return 0
  done < <(sdd_stack_skills "$1")
  return 1
}

ed_error() {
  sdd_finding "error" "$RULE" "$1" "$2"
  sdd_count_error
}

ed_check_served() {
  local file="$1" id="$2" stack
  stack="$(ed_stack_of "$id")"
  if [ -z "$stack" ] || ! printf '%s\n' "$PROFILES" | grep -Fxq -- "$stack"; then
    ed_error "$file" "datastore-unserved: datastore \`$id\` maps to stack id \`$stack\`, which stack.md's profiles: does not list"
    return 1
  fi
  if ! ed_has_persistence "$stack"; then
    ed_error "$file" "datastore-unserved: datastore \`$id\` maps to stack id \`$stack\`, and no stack skill with stack: $stack has a ## Persistence section"
    return 1
  fi
}

ed_reference_targets() {
  local copy="$1" h3 list token key head fseg line
  while IFS= read -r h3; do
    [ -z "$h3" ] && continue
    list="$(kh_constraints_of "$copy" "Fields" "$h3")" || continue
    while IFS= read -r token; do
      [ "$(kh_head_word "$token")" = "references" ] || continue
      printf '%s\t%s\n' "$h3" "$(kh_dotted "$(kh_head_args "$token")")"
    done < <(kh_split_constraints "$list")
  done < <(kh_h3_names "$copy" "Fields")
  while IFS="$KH_FS" read -r key head fseg line; do
    [ -z "$head" ] && continue
    [ "$(kh_head_word "$head")" = "references" ] || continue
    printf 'invariant %s\t%s\n' "$key" "$(kh_dotted "$(kh_head_args "$head")")"
  done < <(kh_entries "$copy" "Invariants" bullet)
}

ed_check_references() {
  local file="$1" own="$2" where target target_file theirs
  kh_strip_comments "$file" > "$ED_TMP"
  while IFS=$'\t' read -r where target; do
    [ -n "$target" ] || continue
    target_file="$(sdd_resolve_entity_id "$target")" || continue
    [ -z "$(ed_embedded "$target_file")" ] || continue
    theirs="$(ed_resolved "$target_file")"
    [ -n "$theirs" ] && [ "$theirs" != "$own" ] || continue
    sdd_finding "warning" "$RULE" "$file" \
      "reference-crosses-datastore: \`$where\` references(\`$target\`) in datastore \`$theirs\` from datastore \`$own\`; no foreign key spans them, so the application keeps the reference"
    sdd_count_warning
  done < <(ed_reference_targets "$ED_TMP")
}

ed_check_into_embedded() {
  local file="$1" where target target_file
  kh_strip_comments "$file" > "$ED_TMP"
  while IFS=$'\t' read -r where target; do
    [ -n "$target" ] || continue
    target_file="$(sdd_resolve_entity_id "$target")" || continue
    [ -n "$(ed_embedded "$target_file")" ] || continue
    sdd_finding "warning" "$RULE" "$file" \
      "embedded-reference: \`$where\` references(\`$target\`), an entity kept inside another entity's row; no foreign key reaches an element of an array, so the application keeps the reference"
    sdd_count_warning
  done < <(ed_reference_targets "$ED_TMP")
}

ed_check_embedded() {
  local file="$1" parent="$2" parent_file named theirs h3 list token word where target
  if ! parent_file="$(sdd_resolve_entity_id "$parent")" || [ "$parent_file" = "$file" ]; then
    ed_error "$file" "embedded-parent-missing: embedded_in: \`$parent\` names no other entity document"
    return 0
  fi
  if [ -n "$(ed_embedded "$parent_file")" ]; then
    ed_error "$file" "embedded-chain: embedded_in: \`$parent\` names an entity that is itself embedded; embedding is one level deep"
  fi
  named="$(ed_named "$file")"
  theirs="$(ed_own "$parent_file")"
  if [ -n "$named" ] && [ "$named" != "$theirs" ]; then
    ed_error "$file" "embedded-datastore: datastore: \`$named\`, and the rows live in \`$parent\`'s row, in datastore \`${theirs:-none}\`; drop datastore: or name the parent's"
  fi
  kh_strip_comments "$file" > "$ED_TMP"
  while IFS= read -r h3; do
    [ -z "$h3" ] || [ "$h3" = "id" ] && continue
    list="$(kh_constraints_of "$ED_TMP" "Fields" "$h3")" || continue
    while IFS= read -r token; do
      word="$(kh_head_word "$token")"
      case "$word" in
        unique|immutable)
          ed_error "$file" "embedded-constraint: \`$h3\` carries \`$word\`, which no store enforces on one element of an array; state the rule as an invariant"
          ;;
      esac
    done < <(kh_split_constraints "$list")
  done < <(kh_h3_names "$ED_TMP" "Fields")
  while IFS=$'\t' read -r where target; do
    [ -n "$target" ] || continue
    sdd_finding "warning" "$RULE" "$file" \
      "embedded-reference: \`$where\` references(\`$target\`) from an entity kept inside another entity's row; no foreign key leaves an element of an array, so the application keeps the reference"
    sdd_count_warning
  done < <(ed_reference_targets "$ED_TMP")
}

check_entity() {
  local file="$1" named resolved parent
  parent="$(ed_embedded "$file")"
  if [ -n "$parent" ]; then
    ed_check_embedded "$file" "$parent"
    return 0
  fi
  ed_check_into_embedded "$file"
  named="$(ed_named "$file")"

  if [ "$COUNT" -eq 0 ]; then
    if [ -n "$DEFAULT" ]; then
      ed_error "$file" "datastore-default-undeclared: stack.md sets default_datastore: \`$DEFAULT\` and declares no datastores:"
    fi
    if [ -n "$named" ]; then
      ed_error "$file" "datastore-undeclared: datastore: \`$named\`, and stack.md declares no datastores:"
    fi
    return 0
  fi

  if [ -n "$named" ]; then
    if ! ed_declared "$named"; then
      ed_error "$file" "datastore-undeclared: datastore: \`$named\` is not in stack.md's datastores:"
      return 0
    fi
    resolved="$named"
  elif [ -z "$DEFAULT" ]; then
    ed_error "$file" "datastore-missing: stack.md declares $COUNT datastores and no default_datastore:, so the entity must name one with datastore:"
    return 0
  elif ! ed_declared "$DEFAULT"; then
    ed_error "$file" "datastore-default-undeclared: the entity names no datastore, and default_datastore: \`$DEFAULT\` is not in stack.md's datastores:"
    return 0
  else
    resolved="$DEFAULT"
  fi

  ed_check_served "$file" "$resolved" || return 0
  ed_check_references "$file" "$resolved"
}

while IFS= read -r entity; do
  [ -n "$entity" ] || continue
  check_entity "$entity"
done < <(sdd_find_entities "$SCOPE")

sdd_exit_with_counters
