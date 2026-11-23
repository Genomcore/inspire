#!/usr/bin/env bash
# .inspire/bin/heading-keys.sh
#
# Rewrites each templated heading of a KB artifact that still carries its English
# section name into the `{id}: {label}` shape: `## Fields` becomes `## ENT4: Fields`,
# and `## Fields: Campos` becomes `## ENT4: Campos`. The ids are `SDD_SECTION_IDS`
# in _lib.sh. A heading that already carries an id, an unknown heading, and
# anything inside frontmatter, a fence or an HTML comment are left as they are.
#
# Usage:
#   .inspire/bin/heading-keys.sh --list [path...]   # print `{file}<TAB>{count}`, write nothing
#   .inspire/bin/heading-keys.sh [path...]          # rewrite, print `rewrote<TAB>{file}<TAB>{count}`

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

KINDS="action entity feature adr screen pattern component layout module store spike"

MODE="rewrite"
if [ "${1:-}" = "--list" ]; then
  MODE="list"
  shift
fi
[ $# -eq 0 ] && set -- "$SDD_KB_ROOT"

find_flat() {
  local scope="$1" layer="$2"
  [ -e "$scope" ] || return 0
  find "$scope" -type f -name "*.md" 2>/dev/null \
    | awk -F"(^|/)$layer/" '
        NF > 1 && $NF !~ /\// && $NF != "README.md" && $NF != "_index.md" { print }
      ' \
    | sort
}

files_of_kind() {
  local kind="$1" scope="$2"
  case "$kind" in
    action) sdd_find_actions "$scope" ;;
    entity) sdd_find_entities "$scope" ;;
    feature) sdd_find_features "$scope" ;;
    adr) sdd_find_adrs "$scope"; sdd_find_adr_rationales "$scope" ;;
    screen) sdd_find_screens "$scope" ;;
    pattern) sdd_find_catalog "$scope" patterns ;;
    component) sdd_find_catalog "$scope" components ;;
    layout) sdd_find_catalog "$scope" layouts ;;
    module) sdd_find_modules "$scope" ;;
    store) sdd_find_stores "$scope" ;;
    spike) find_flat "$scope" 06_spikes ;;
  esac
}

rewrite_headings() {
  awk -v kind="$2" '
      NR == 1 && $0 == "---" { fm = 1; print; next }
      fm { if ($0 == "---") fm = 0; print; next }
      sdd_fence($0) { print; next }
      sdd_in_fence() { print; next }
      BEGIN {
        n = split(ENVIRON["SDD_SECTION_IDS"], rows, "\n")
        for (i = 1; i <= n; i++) {
          split(rows[i], f, "\t")
          if (f[1] == kind) id_of[f[4] ">" f[3]] = f[2]
        }
      }
      {
        line = $0; rest = line; visible = ""
        while (rest != "") {
          if (incomment) {
            p = index(rest, "-->"); if (p == 0) { rest = ""; break }
            rest = substr(rest, p + 3); incomment = 0
          } else {
            p = index(rest, "<!--"); if (p == 0) { visible = visible rest; break }
            visible = visible substr(rest, 1, p - 1); rest = substr(rest, p + 4); incomment = 1
          }
        }
        if (visible != line) { print; next }
      }
      /^## / {
        parent = sdd_heading_name($0, "## ")
        if (relabel($0, "## ", ">")) next
      }
      /^### / { if (relabel($0, "### ", parent ">")) next }
      { print }
      END { print count + 0 > "/dev/stderr" }
      function relabel(line, prefix, scope,   key, label) {
        key = sdd_heading_key(line, prefix)
        if (!((scope key) in id_of)) return 0
        label = substr(line, length(prefix) + 1)
        if (index(label, ": ") > 0) label = substr(label, index(label, ": ") + 2)
        else { sub(/:?[[:space:]]*$/, "", label) }
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", label)
        print prefix id_of[scope key] ": " label
        count++
        return 1
      }
    '"${SDD_AWK_FENCE_FUNCS}${SDD_AWK_HEADING_FUNCS}" "$1"
}

status=0
for kind in $KINDS; do
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    count="$(rewrite_headings "$file" "$kind" 2>&1 >"$file.tmp")"
    case "$count" in ''|*[!0-9]*) false ;; esac || {
      rm -f "$file.tmp"; printf 'failed\t%s\n' "$file"; status=1; continue
    }
    if [ "$count" = "0" ] || [ "$MODE" = "list" ]; then
      rm -f "$file.tmp"
      [ "$count" != "0" ] && printf '%s\t%s\n' "$file" "$count"
      continue
    fi
    mv "$file.tmp" "$file"
    printf 'rewrote\t%s\t%s\n' "$file" "$count"
  done < <(for scope in "$@"; do files_of_kind "$kind" "$scope"; done | sort -u)
done

exit "$status"
