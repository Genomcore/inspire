#!/usr/bin/env bash
# .inspire/bin/type-cells.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"
RULE="type-cells"
SEMANTIC_TYPES="$SDD_BOOTSTRAP_ROOT/semantic-types.md"

PROJECT_TYPES="$(mktemp -t sdd-type-cells.XXXXXX)"
trap 'rm -f "$PROJECT_TYPES"' EXIT

if [ -f "$SEMANTIC_TYPES" ]; then
  awk '
    !/^\|/ { tab = 0; next }
    !tab { tab = 1; next }
    {
      n = split($0, c, "|")
      name = c[2]; base = (n >= 3) ? c[3] : ""
      gsub(/`/, "", name); gsub(/`/, "", base)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", base)
      if (name == "" || name ~ /^:?-+:?$/) next
      print name "\t" base
    }
  ' "$SEMANTIC_TYPES" > "$PROJECT_TYPES"
fi

type_rows() {
  local file="$1" section="$2" label="$3"
  sdd_body_section "$file" "$section" | awk -v label="$label" '
    !/^\|/ { tab = 0; next }
    !tab { tab = 1; next }
    {
      n = split($0, c, "|")
      name = c[2]
      gsub(/`/, "", name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == "" || name ~ /^:?-+:?$/) next
      printf "%s `%s`\t%s\n", label, name, (n >= 4) ? c[3] : ""
    }
  '
}

entity_rows() {
  sdd_entities_touched "$1" | awk -F'\t' '{ printf "`%s` field `%s`\t%s\n", $1, $2, $4 }'
}

classify() {
  awk -F'\t' -v types="$PROJECT_TYPES" '
    BEGIN {
      split("email uuid timestamp date password string integer number boolean json enum", u, " ")
      for (i in u) universal[u[i]] = 1
      alias["int"] = "integer"; alias["bool"] = "boolean"; alias["text"] = "string"
      while ((getline line < types) > 0) {
        split(line, p, "\t")
        if (!(p[1] in project)) project[p[1]] = p[2]
      }
    }
    function head(t) { sub(/<.*/, "", t); return t }
    {
      where = $1; t = $2
      gsub(/`/, "", t)
      gsub(/[[:space:]]+/, " ", t)
      gsub(/^ | $/, "", t)
      if (t == "" || t == "-" || t == "—" || t == "–") {
        print "type-empty: " where " declares no type"
        next
      }
      use = ""
      if (t in alias) use = alias[t]
      else if (t ~ /^varchar([( ]|$)/) use = "string"
      else if (t ~ /^numeric([( ]|$)/) use = "number"
      if (use != "") {
        print "type-alias: " where " is typed `" t "`, a rejected alias: use `" use "`"
        next
      }
      if (head(t) in universal) next
      if (!(t in project)) {
        print "type-unknown: " where " is typed `" t "`, which is in neither the universal vocabulary nor 00_bootstrap/semantic-types.md"
        next
      }
      base = project[t]
      if (base == "") print "type-no-base: " where " is typed `" t "`, a project type that declares no base type"
      else if (!(head(base) in universal)) print "type-no-base: " where " is typed `" t "`, a project type whose base `" base "` is not a universal type"
    }
  '
}

report() {
  local file="$1" severity message
  severity="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"
  while IFS= read -r message; do
    [ -n "$message" ] || continue
    sdd_finding "$severity" "$RULE" "$file" "$message"
    sdd_count_by_severity "$severity"
  done
}

while IFS= read -r entity; do
  [ -n "$entity" ] || continue
  report "$entity" < <(type_rows "$entity" "Fields" "field" | classify)
done < <(sdd_find_entities "$SCOPE")

while IFS= read -r action; do
  [ -n "$action" ] || continue
  report "$action" < <({
    type_rows "$action" "Inputs" "input"
    type_rows "$action" "Outputs" "output"
    entity_rows "$action"
  } | classify)
done < <(sdd_find_actions "$SCOPE")

sdd_exit_with_counters
