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
  local file="$1" section="$2" kind="$3"
  sdd_body_section "$file" "$section" | awk -v kind="$kind" '
    !/^\|/ { tab = 0; next }
    !tab { tab = 1; next }
    {
      n = split($0, c, "|")
      name = c[2]
      gsub(/`/, "", name)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == "" || name ~ /^:?-+:?$/) next
      printf "%s\t%s `%s`\t%s\t%s\n", kind, kind, name, name, (n >= 4) ? c[3] : ""
    }
  '
}

entity_rows() {
  sdd_entities_touched "$1" | awk -F'\t' '{ printf "touch\t`%s` field `%s`\t%s\t%s\n", $1, $2, $2, $4 }'
}

classify() {
  awk -F'\t' -v types="$PROJECT_TYPES" '
    BEGIN {
      split("email uuid timestamp date password string integer number boolean json enum record", u, " ")
      for (i in u) universal[u[i]] = 1
      alias["int"] = "integer"; alias["bool"] = "boolean"; alias["text"] = "string"
      NONE = "\001"
      while ((getline line < types) > 0) {
        split(line, p, "\t")
        if (!(p[1] in project)) project[p[1]] = p[2]
      }
    }
    function head(t) { sub(/<.*/, "", t); return t }
    function element(t,    e) {
      if (t !~ /^list<.*>$/) return NONE
      e = substr(t, 6, length(t) - 6)
      gsub(/^ | $/, "", e)
      return e
    }
    function clean(t) {
      gsub(/`/, "", t)
      gsub(/[[:space:]]+/, " ", t)
      gsub(/^ | $/, "", t)
      return t
    }
    function hint(t) {
      if (t == "list") return "; write `list<T>` with its element type"
      if (t ~ /^array</) return "; write `list<T>`"
      if (t == "object") return "; write `record`"
      return ""
    }
    function resolve(t,    e, use, base, inner, r) {
      if (t == "" || t == "-" || t == "—" || t == "–") return "type-empty\tdeclares no type"
      use = ""
      if (t in alias) use = alias[t]
      else if (t ~ /^varchar([( ]|$)/) use = "string"
      else if (t ~ /^numeric([( ]|$)/) use = "number"
      if (use != "") return "type-alias\tis typed `" t "`, a rejected alias: use `" use "`"
      e = element(t)
      if (e != NONE) {
        if (e == "" || element(e) != NONE) return "type-unknown\tis typed `" t "`, a list whose element type is missing or is itself a list"
        inner = resolve(e)
        if (inner == "") return ""
        split(inner, r, "\t")
        return r[1] "\tis typed `" t "`, whose element " r[2]
      }
      if (head(t) in universal && !(t == "record" && (t in project))) return ""
      if (!(t in project)) return "type-unknown\tis typed `" t "`, which is in neither the universal vocabulary nor 00_bootstrap/semantic-types.md" hint(t)
      base = project[t]
      if (base == "") return "type-no-base\tis typed `" t "`, a project type that declares no base type"
      if (element(base) != NONE) return ""
      if (!(head(base) in universal)) return "type-no-base\tis typed `" t "`, a project type whose base `" base "` is not a universal type"
      return ""
    }
    function is_record(t) { return t == "record" && !("record" in project) }
    function holds_record(t) { return is_record(t) || (element(t) != NONE && is_record(element(t))) }
    function is_new(t) { return is_record(t) || element(t) != NONE }
    function fits(t, want) { return want == "record" ? is_record(t) : (element(t) != NONE && is_record(element(t))) }
    function legacy(key, message) {
      if (key in warned) return
      warned[key] = 1
      print "warning\ttype-record-legacy: " message
    }
    {
      kind = $1; where = $2; name = $3; t = clean($4)
      verdict = resolve(t)
      if (verdict != "") {
        split(verdict, v, "\t")
        print v[1] ": " where " " v[2]
      }
      nested = (name ~ /\./ || name ~ /\[\]/)
      if (kind == "field" || kind == "touch") {
        if (holds_record(t)) print "type-record-misplaced: " where " is typed `" t "`, and a record is declared only in the ## Inputs or ## Outputs of an action"
        else if (nested) legacy(kind SUBSEP name, where " is a nested row; an entity field is stored, so name it without `.` or `[]`, or declare the record in an action\047s ## Inputs or ## Outputs")
        next
      }
      row[kind, name] = t
      order[++rows] = kind SUBSEP name
      label[kind, name] = where
    }
    END {
      for (i = 1; i <= rows; i++) {
        split(order[i], key, SUBSEP)
        kind = key[1]; name = key[2]
        if (name ~ /\./) {
          parent = name
          sub(/\.[^.]*$/, "", parent)
          want = "record"
          if (parent ~ /\[\]$/) { sub(/\[\]$/, "", parent); want = "list<record>" }
          if (!((kind, parent) in row)) legacy(kind SUBSEP parent, label[kind, name] " sits under `" parent "`, which has no row of its own; add a `" parent "` row typed `" want "`")
          else if (fits(row[kind, parent], want)) has_child[kind, parent] = 1
          else if (is_new(row[kind, parent])) print "type-record-rows: " label[kind, name] " sits under `" parent "`, which is not typed `" want "`"
          else legacy(kind SUBSEP parent, label[kind, parent] " is typed `" row[kind, parent] "` and has rows of its own; type it `" want "` so they are checked as its fields")
        } else if (name ~ /\[\]/) {
          base = name
          sub(/\[\].*$/, "", base)
          legacy(kind SUBSEP name, label[kind, name] " ends in `[]`; name the row `" base "` and type it `list<" row[kind, name] ">`")
        }
      }
      for (i = 1; i <= rows; i++) {
        split(order[i], key, SUBSEP)
        kind = key[1]; name = key[2]; t = row[kind, name]
        if (!holds_record(t) || ((kind, name) in has_child)) continue
        sub_row = is_record(t) ? name ".{field}" : name "[].{field}"
        print "type-record-rows: " label[kind, name] " is typed `" t "` and no `" sub_row "` row declares its fields"
      }
    }
  '
}

report() {
  local file="$1" ramp severity message
  ramp="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"
  while IFS= read -r message; do
    [ -n "$message" ] || continue
    severity="$ramp"
    case "$message" in
      warning$'\t'*) severity="warning"; message="${message#warning$'\t'}" ;;
    esac
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
