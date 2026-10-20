#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"
SCREENS_ROOT="$SDD_KB_ROOT/05_screens"
LAYOUTS_DIR="$SCREENS_ROOT/layouts"
COMPONENTS_DIR="$SCREENS_ROOT/components"

emit() {
  sdd_finding "warning" "screen-presentation" "$1" "$2"
  sdd_count_warning
}

header_targets() {
  awk -v pfx="$2" '
    /^---[ \t]*$/ && NR == 1 { fm = 1; next }
    fm { if ($0 ~ /^---[ \t]*$/) fm = 0; next }
    index($0, pfx) == 1 {
      s = $0
      while (match(s, /\[\[[^]]+\]\]/)) {
        t = substr(s, RSTART + 2, RLENGTH - 4)
        p = index(t, "|")
        if (p > 0) t = substr(t, 1, p - 1)
        sub(/#.*/, "", t)
        n = split(t, seg, "/")
        print seg[n]
        s = substr(s, RSTART + RLENGTH)
      }
      exit
    }
  ' "$1"
}

table_rows() {
  sdd_body_section "$1" "$2" | awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /<!--/ { incomment = 1 }
    incomment { if ($0 ~ /-->/) incomment = 0; next }
    /^[ \t]*\|/ {
      probe = $0
      gsub(/[ \t|:-]/, "", probe)
      if (probe == "") next
      line = $0
      gsub(/\\\|/, "\001", line)
      sub(/^[ \t]*\|/, "", line)
      sub(/\|[ \t]*$/, "", line)
      n = split(line, cell, "|")
      out = ""
      for (i = 1; i <= n; i++) {
        c = trim(cell[i]); gsub(/\001/, "|", c)
        out = out (i > 1 ? "\t" : "") c
      }
      print out
    }
  '
}

source_kind() {
  local source
  source="$(printf '%s' "$1" | tr -d '`' | tr '[:upper:]' '[:lower:]')"
  case "$source" in
    *design-system.md*|*design-tokens.json*) printf 'decided' ;;
    reference|prototype) printf 'reference' ;;
    generated) printf 'generated' ;;
    undecided) printf 'undecided' ;;
    as\ *) printf 'decided' ;;
    "") printf 'missing' ;;
    *) printf 'unknown' ;;
  esac
}

check_sourced_table() {
  local file="$1" section="$2" first=1 row label source kind
  local open_rows="" open_n=0
  while IFS= read -r row; do
    if [ "$first" = 1 ]; then first=0; continue; fi
    if [ "$section" = "Breakpoints" ]; then
      label="$(printf '%s' "$row" | cut -f1,2 | tr -d '`' | sed 's/\t/ · /')"
    else
      label="$(printf '%s' "$row" | cut -f1 | tr -d '`')"
    fi
    source="$(printf '%s' "$row" | awk -F'\t' '{ print $NF }')"
    kind="$(source_kind "$source")"
    case "$kind" in
      missing)
        emit "$file" "layout $section: row '$label' carries no Source — design-system.md, design-tokens.json, reference, generated, undecided or as {layout}" ;;
      unknown)
        emit "$file" "layout $section: row '$label' has Source '$source', outside the closed vocabulary (design-system.md §… | design-tokens.json | reference | generated | undecided | as {layout})" ;;
      generated|undecided)
        open_rows="$open_rows '$label' ($kind)"
        open_n=$((open_n + 1)) ;;
    esac
  done < <(table_rows "$file" "$section")
  if [ "$open_n" -gt 0 ]; then
    emit "$file" "layout $section: $open_n row(s) decided by nobody yet —$open_rows; confirm each through /inspire-bootstrap design-system"
  fi
  printf '%s\n' "$open_n" > "$OPEN_COUNT"
}

check_layout_entry() {
  local file="$1" open_total=0 section state
  for section in Geometry Breakpoints; do
    if ! sdd_has_section "$file" "$section"; then
      emit "$file" "layout entry declares no '## $section' table"
      continue
    fi
    check_sourced_table "$file" "$section"
    open_total=$((open_total + $(cat "$OPEN_COUNT")))
  done
  state="$(sdd_catalog_state "$file")"
  if [ "$state" = "implemented" ] && [ "$open_total" -gt 0 ]; then
    emit "$file" "layout entry is implemented with $open_total generated or undecided row(s): a frame nobody decided is not a frame the code stands behind"
  fi
}

check_screen_layout() {
  local file="$1" pattern layout layout_file framed
  pattern="$(header_targets "$file" '**Pattern:**' | head -n 1)"
  layout="$(header_targets "$file" '**Layout:**' | head -n 1)"
  if [ -z "$layout" ]; then
    [ -n "$pattern" ] && emit "$file" "screen names pattern $pattern and no '**Layout:**': its frame's geometry is recorded nowhere"
    return 0
  fi
  layout_file="$LAYOUTS_DIR/$layout.md"
  [ -f "$layout_file" ] || return 0
  [ -n "$pattern" ] || return 0
  framed="$(header_targets "$layout_file" '**Pattern:**' | tr '\n' ' ')"
  [ -n "$framed" ] || return 0
  case " $framed" in
    *" $pattern "*) ;;
    *) emit "$file" "layout $layout frames ${framed% } and this screen names pattern $pattern" ;;
  esac
}

render_records() {
  sdd_body_section "$1" "Render" | awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function cells(line,   n) {
      gsub(/\\\|/, "\001", line)
      sub(/^[ \t]*\|/, "", line)
      sub(/\|[ \t]*$/, "", line)
      n = split(line, cell, "|")
      for (i = 1; i <= n; i++) { cell[i] = trim(cell[i]); gsub(/\001/, "|", cell[i]) }
      return n
    }
    /<!--/ { incomment = 1 }
    incomment { if ($0 ~ /-->/) incomment = 0; next }
    /^### / { h3 = substr($0, 5); intable = 0; next }
    !/^[ \t]*\|/ { intable = 0; next }
    {
      probe = $0
      gsub(/[ \t|:-]/, "", probe)
      if (probe == "") next
      n = cells($0)
      if (!intable) {
        intable = 1; comp = 0; narrow = 0
        for (i = 1; i <= n; i++) {
          name = tolower(cell[i])
          if (name == "component") comp = i
          if (name == "narrow") narrow = i
        }
        if (!narrow && tolower(h3) ~ /table|column/) print "NONARROW\037" h3
        next
      }
      printf "ROW\037%s\037%s\037%s\037%s\n", cell[1], (comp ? cell[comp] : ""), (narrow ? "1" : "0"), (narrow ? cell[narrow] : "")
    }
  '
}

check_screen_render() {
  local file="$1" kind value component has_narrow narrow part name
  if ! sdd_has_section "$file" "Render"; then
    sdd_has_subsection "$file" "Bindings" "Data" \
      && emit "$file" "screen declares data and no '## Render' table binding each value to a field type, a component, a treatment and an alignment"
    return 0
  fi
  while IFS=$'\037' read -r kind value component has_narrow narrow; do
    if [ "$kind" = "NONARROW" ]; then
      emit "$file" "render table '$value' lists a table's columns and carries no Narrow column: say what each column does below the widest range"
      continue
    fi
    value="$(printf '%s' "$value" | tr -d '`')"
    if [ "$has_narrow" = 1 ]; then
      narrow="$(printf '%s' "$narrow" | tr -d '`' | tr '[:upper:]' '[:lower:]')"
      case "$narrow" in
        always|sticky|scroll|—|-|"hidden below "*|"hidden < "*) ;;
        *) emit "$file" "render row '$value' has Narrow '$narrow': always, sticky, scroll, hidden below {width}, or — for a row that is not a column" ;;
      esac
    fi
    while IFS= read -r part; do
      name="$(printf '%s' "$part" | grep -oE '`[^`]+`' | head -n 1 | tr -d '`')"
      [ -n "$name" ] || continue
      case "$name" in -*|*[![:lower:][:digit:]-]*) continue ;; esac
      [ -f "$COMPONENTS_DIR/$name.md" ] && continue
      emit "$file" "render row '$value' draws with component '$name', which has no components/ entry: write it at to-extract in the same turn"
    done < <(printf '%s\n' "$component" | tr '+' '\n')
  done < <(render_records "$file")
}

check_touch() {
  local file="$1" body
  body="$(awk '
    /^---[ \t]*$/ && NR == 1 { fm = 1; next }
    fm { if ($0 ~ /^---[ \t]*$/) fm = 0; next }
    /^## Notes/ { skip = 1; next }
    /^## / { skip = 0 }
    /<!--/ { incomment = 1 }
    incomment { if ($0 ~ /-->/) incomment = 0; next }
    !skip { print }
  ' "$file")"
  printf '%s' "$body" | grep -qi 'hover' || return 0
  printf '%s' "$body" | grep -qiE 'touch|tap|long-press|long press' && return 0
  emit "$file" "names a hover affordance and no touch equivalent: give it a tap or long-press path"
}

SCOPE_DIR="$(sdd_scope_intersect "$SCOPE" "$SCREENS_ROOT")"
[ -n "$SCOPE_DIR" ] || exit 0

OPEN_COUNT="$(mktemp -t sdd-open-count.XXXXXX)"
trap 'rm -f "$OPEN_COUNT"' EXIT

while IFS= read -r screen_file; do
  [ -z "$screen_file" ] && continue
  check_screen_layout "$screen_file"
  check_screen_render "$screen_file"
  check_touch "$screen_file"
done < <(sdd_find_screens "$SCOPE_DIR")

while IFS= read -r catalog_file; do
  [ -n "$catalog_file" ] && check_layout_entry "$catalog_file"
done < <(sdd_find_catalog "$SCOPE_DIR" layouts)

while IFS= read -r catalog_file; do
  [ -n "$catalog_file" ] && check_touch "$catalog_file"
done < <(sdd_find_catalog "$SCOPE_DIR" components)

sdd_exit_with_counters
