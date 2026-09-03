#!/usr/bin/env bash
# .inspire/bin/lib/derive-types.sh
#
# Library — semantic-type resolution for the derived contract. Sourced after
# `_lib.sh`; carries no dependency on the other derive units.
#
# WHY THE VOCABULARY IS DATA HERE. Every `Type` cell in the KB has to resolve to
# a universal base type before anything can render it, and a deployed bin script
# may not reach into `.claude/skills/` to find out what the universal vocabulary
# is: a project may have edited, moved or deleted a skill directory and still be
# entitled to a correct derivation. So the vocabulary ships as the list below,
# and `test-derive-lib.sh` asserts that list equals the table in
# `inspire-domain/references/type-mapping.md` row for row. The doc stays the
# authority a human reads; the test is what keeps the two from drifting.
#
# THREE HOMES, IN ORDER (type-mapping.md § Extension rules):
#   1. the universal vocabulary below — base type is the type itself;
#   2. the project's own types in `$SDD_KB_ROOT/00_bootstrap/semantic-types.md`,
#      whose mandatory `Base type` column names a universal one;
#   3. nothing — which is a derivation refusal (`DR-T1`), never a generic
#      emission, per D5.
#
# `enum<…>` is parametric: the universal row is `enum<A,B,C>` and its base NAME
# is `enum`, so a field typed `enum<draft|active>` resolves to base `enum`. The
# angle-bracket payload is the descriptor's, never the vocabulary's.

# The `Semantic` column of type-mapping.md § The vocabulary, in document order.
DERIVE_UNIVERSAL_TYPES="email uuid timestamp date password string integer number boolean json enum<A,B,C>"

# derive_type_basename <type> — a type string reduced to the name a vocabulary
# row is keyed on: everything before the first `<`.
derive_type_basename() {
  printf '%s' "${1%%<*}"
}

# derive_is_universal <name> — exit 0 when the name is a universal type's base
# name.
derive_is_universal() {
  local t
  for t in $DERIVE_UNIVERSAL_TYPES; do
    [ "$(derive_type_basename "$t")" = "$1" ] && return 0
  done
  return 1
}

# derive_project_types — `type<TAB>base` for every row of the project's own
# semantic-types table, read once per run into $DERIVE_PROJECT_TYPES. An absent
# file is the common case (the skeleton ships the table empty), not an error.
DERIVE_PROJECT_TYPES=""
derive_project_types() {
  [ -z "$DERIVE_PROJECT_TYPES" ] || { printf '%s\n' "$DERIVE_PROJECT_TYPES"; return 0; }
  DERIVE_PROJECT_TYPES="$DERIVE_TMP/project-types.tsv"
  : > "$DERIVE_PROJECT_TYPES"
  local f="$SDD_KB_ROOT/00_bootstrap/semantic-types.md"
  [ -f "$f" ] || { printf '%s\n' "$DERIVE_PROJECT_TYPES"; return 0; }
  awk -F'|' '
    /^[[:space:]]*\|/ {
      name = $2; base = $3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", base)
      gsub(/`/, "", name); gsub(/`/, "", base)
      if (name == "" || name == "Type" || name ~ /^-+$/) next
      print name "\t" base
    }
  ' "$f" > "$DERIVE_PROJECT_TYPES"
  printf '%s\n' "$DERIVE_PROJECT_TYPES"
}

# derive_type_base <type> — prints the base type. The three failures are three
# refusal classes, so they are three exit codes: 1 no type declared (an empty
# cell or the `—` none-spelling), 2 the type is in neither home, 3 a project
# type whose declared base type is missing or not universal.
derive_type_base() {
  local name base
  name="$(derive_norm "$1")"
  name="${name//\`/}"
  case "$name" in ''|'—'|'-'|'–') return 1 ;; esac
  if derive_is_universal "$(derive_type_basename "$name")"; then
    derive_type_basename "$name"
    return 0
  fi
  base="$(awk -F'\t' -v k="$name" '$1 == k { print $2; exit }' "$(derive_project_types)")"
  [ -n "$base" ] || return 2
  base="$(derive_type_basename "$base")"
  derive_is_universal "$base" || return 3
  printf '%s' "$base"
}
