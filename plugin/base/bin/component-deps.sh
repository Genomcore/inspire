#!/usr/bin/env bash
# .inspire/bin/component-deps.sh
#
# Rule: a component entry declares the catalog components it renders, and the
# components it declares can be built in some order.
#   - error:   a circle of ordering edges between components, every entry of it in
#              order, reported on each entry of the circle in scope;
#   - error:   a link on `**Components:**` or `**Deferred components:**` that names
#              a file other than a component entry;
#   - warning: a catalog component named in `## CMP1: Structure` (in backticks or
#              by a link) that neither line lists; a name in backticks right after
#              "as", "like", "of" or "from" compares with it, and is not a use;
#   - warning: a component that lists itself, or lists one component on both lines.
#
# The ordering edges are the ones INSPIRE Factory builds by
# (_references/derived-contract.md § requires): a link on `**Components:**` makes
# the entry wait for its target, and a link on `**Deferred components:**` makes the
# target wait for the entry. A component on both lines is an ordering edge, and a
# component never waits for itself.
#
# A broken link adds no edge: links-resolve.sh reports it.
#
# Usage:
#   .inspire/bin/component-deps.sh                       # scan whole tree
#   .inspire/bin/component-deps.sh inspire_kb/01_spec/_design-system   # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_link-reads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"
RULE="component-deps"

WORK="$(mktemp -d -t sdd-component-deps.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

emit() {
  sdd_finding "$1" "$RULE" "$2" "$3"
  sdd_count_by_severity "$1"
}

component_id() {
  local base="${1##*/}"
  printf '%s\n' "${base%.component.md}"
}

header_line() {
  awk -v pfx="$2" "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      index($0, pfx) == 1 { print NR; exit }
    '"${SDD_AWK_FENCE_FUNCS}" "$1"
}

header_targets() {
  local file="$1" line="$2" ln form target text path
  [ -n "$line" ] || return 0
  sdd_line_links "$file" "$line" "$line" | while IFS=$'\t' read -r ln form target text path; do
    [ "$form" = wiki ] && continue
    [ -n "$path" ] || continue
    printf '%s\t%s\n' "$target" "$path"
  done
}

structure_names() {
  local file="$1" ln form target text path
  sdd_body_section "$file" "Structure" \
    | awk '
        /<!--/ { incomment = 1 }
        incomment { if ($0 ~ /-->/) incomment = 0; next }
        {
          line = $0
          while (match(line, /`[^`]+`/)) {
            before = tolower(substr(line, 1, RSTART - 1))
            if (before !~ /(^|[^a-z])(as|like|of|from)[ \t]+$/) print substr(line, RSTART + 1, RLENGTH - 2)
            line = substr(line, RSTART + RLENGTH)
          }
        }
      '
  sdd_section_links "$file" "Structure" | while IFS=$'\t' read -r ln form target text path; do
    case "$path" in *.component.md) component_id "$path" ;; esac
  done
}

sdd_find_catalog "$SDD_SPEC_ROOT" components > "$WORK/all"
sdd_find_catalog "$SCOPE" components > "$WORK/scope"
while IFS= read -r f; do
  [ -n "$f" ] && printf '%s\t%s\n' "$(component_id "$f")" "$f"
done < "$WORK/all" > "$WORK/ids"
: > "$WORK/edges"

in_scope() {
  grep -qxF -- "$1" "$WORK/scope"
}

path_of() {
  awk -F'\t' -v id="$1" '$1 == id { print $2; exit }' "$WORK/ids"
}

while IFS= read -r file; do
  [ -n "$file" ] || continue
  self="$(component_id "$file")"
  report=0
  in_scope "$file" && report=1
  : > "$WORK/listed"

  for kind in strong deferred; do
    if [ "$kind" = strong ]; then label='**Components:**'; else label='**Deferred components:**'; fi
    while IFS=$'\t' read -r target path; do
      [ -n "$path" ] || continue
      case "$path" in
        *.component.md) ;;
        *)
          [ "$report" = 1 ] && emit error "$file" \
            "component link names no component entry: $label links \`$target\`, which is not a \`*.component.md\` file; list only catalog components there"
          continue
          ;;
      esac
      to="$(component_id "$path")"
      if [ "$to" = "$self" ]; then
        [ "$report" = 1 ] && emit warning "$file" \
          "component lists itself: $label names \`$self\`; a component never waits for itself, so remove the link"
        continue
      fi
      printf '%s\t%s\n' "$kind" "$to" >> "$WORK/listed"
    done < <(header_targets "$file" "$(header_line "$file" "$label")")
  done

  while IFS= read -r to; do
    [ -n "$to" ] || continue
    if grep -qxF -- "strong"$'\t'"$to" "$WORK/listed"; then
      [ "$report" = 1 ] && emit warning "$file" \
        "component listed on both lines: \`$to\` is on **Components:** and on **Deferred components:**; it is built first, as **Components:** says, so remove it from one of the two lines"
    else
      printf '%s\t%s\t%s\t%s\n' "$to" "$self" deferred "$self" >> "$WORK/edges"
    fi
  done < <(awk -F'\t' '$1 == "deferred" { print $2 }' "$WORK/listed" | sort -u)

  while IFS= read -r to; do
    [ -n "$to" ] && printf '%s\t%s\t%s\t%s\n' "$self" "$to" strong "$self" >> "$WORK/edges"
  done < <(awk -F'\t' '$1 == "strong" { print $2 }' "$WORK/listed" | sort -u)

  [ "$report" = 1 ] || continue
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" != "$self" ] || continue
    grep -q -- $'\t'"$name"'$' "$WORK/listed" && continue
    [ -n "$(path_of "$name")" ] || continue
    emit warning "$file" \
      "component used without an edge: \`$name\` is named in ## CMP1: Structure and is on neither **Components:** nor **Deferred components:**; list it on **Components:** if this component renders it"
  done < <(structure_names "$file" | sort -u)
done < "$WORK/all"

[ -s "$WORK/edges" ] || { sdd_exit_with_counters; exit $?; }

LC_ALL=C sort -u "$WORK/edges" | awk -F'\t' '
  {
    from = $1; to = $2
    if (!(from in seen)) { seen[from] = 1; nodes[++n] = from }
    if (!(to in seen)) { seen[to] = 1; nodes[++n] = to }
    adj[from] = adj[from] (adj[from] == "" ? "" : " ") to
  }
  function visit(u,    k, list, i, v, j, cyc, start, best, rot, key) {
    color[u] = 1
    stack[++depth] = u
    k = split(adj[u], list, " ")
    for (i = 1; i <= k; i++) {
      v = list[i]
      if (color[v] == 1) {
        for (j = depth; j >= 1; j--) if (stack[j] == v) { start = j; break }
        best = start
        for (j = start; j <= depth; j++) if (stack[j] < stack[best]) best = j
        rot = ""
        for (j = best; j <= depth; j++) rot = rot (rot == "" ? "" : " ") stack[j]
        for (j = start; j < best; j++) rot = rot " " stack[j]
        if (!(rot in found)) { found[rot] = 1; print rot }
      } else if (color[v] == 0) {
        visit(v)
      }
    }
    depth--
    color[u] = 2
  }
  END {
    for (i = 1; i <= n; i++) color[nodes[i]] = 0
    for (i = 1; i <= n; i++) if (color[nodes[i]] == 0) visit(nodes[i])
  }
' > "$WORK/circles"

why_edge() {
  local from="$1" to="$2"
  if awk -F'\t' -v a="$from" -v b="$to" '$1 == a && $2 == b && $3 == "strong" { f = 1 } END { exit !f }' "$WORK/edges"; then
    printf '`%s` lists `%s` on **Components:**' "$from" "$to"
  else
    printf '`%s` lists `%s` on **Deferred components:**' "$to" "$from"
  fi
}

while IFS= read -r circle; do
  [ -n "$circle" ] || continue
  read -r -a members <<< "$circle"
  count="${#members[@]}"
  chain=""
  reasons=""
  for ((i = 0; i < count; i++)); do
    from="${members[$i]}"
    to="${members[$(( (i + 1) % count ))]}"
    chain="$chain\`$from\` → "
    reasons="$reasons${reasons:+; }$(why_edge "$from" "$to")"
  done
  chain="$chain\`${members[0]}\`"
  for member in "${members[@]}"; do
    path="$(path_of "$member")"
    [ -n "$path" ] && in_scope "$path" || continue
    emit error "$path" \
      "circle of components: $chain has no build order ($reasons). Move one link of the circle to **Deferred components:** in the entry that can be built without the other, or move the shared part into a new component both use"
  done
done < "$WORK/circles"

sdd_exit_with_counters
