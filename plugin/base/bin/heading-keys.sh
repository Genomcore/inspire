#!/usr/bin/env bash
# .inspire/bin/heading-keys.sh
#
# Rewrites each bare templated heading of a KB artifact into the `{key}: {label}`
# shape, with the key as its English label: `## Fields` becomes `## Fields: Fields`.
# A heading that already carries a label, an unknown heading, and anything inside
# frontmatter, a fence or an HTML comment are left as they are.
#
# Usage:
#   .inspire/bin/heading-keys.sh --list [path...]   # print `{file}<TAB>{count}`, write nothing
#   .inspire/bin/heading-keys.sh [path...]          # rewrite, print `rewrote<TAB>{file}<TAB>{count}`
#   .inspire/bin/heading-keys.sh --keys             # print `{kind}<TAB>{heading}` for every key

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

KEYS_action='Purpose|Inputs|Outputs|Entities|Preconditions|Behavior|Postconditions|Errors'
KEYS_entity='Purpose|Rationale|Invariants|Fields|Touched by'
KEYS_feature='Actor|Preconditions|Main flow|Alternative flows|Error flows|Postconditions|Acceptance criteria'
KEYS_adr='Context|Decision|Consequences|Consequences>Breaking changes|Alternatives considered|Related ADRs'
KEYS_screen='Purpose|Bindings|Bindings>Parameters|Bindings>Data|Bindings>Dispatches|Bindings>Navigation|Bindings>States|Render|Module-specific deviations|Current prototype|Notes'
KEYS_pattern='Structure|Regions|Variants|Notes'
KEYS_component='Structure|API / Slots|States|Variants|Instances'
KEYS_layout='Frame|Geometry|Breakpoints|Composition|Variants|Adopters|Notes'
KEYS_module='Overview|Relationships|Use cases|Screens|Domain|Module ADRs'
KEYS_spike='Question|Scope|Learnings|Outcome'
KINDS="action entity feature adr screen pattern component layout module spike"

MODE="rewrite"
case "${1:-}" in
  --list) MODE="list"; shift ;;
  --keys)
    for kind in $KINDS; do
      eval "keys=\$KEYS_$kind"
      printf '%s\n' "$keys" | tr '|' '\n' | while IFS= read -r key; do
        case "$key" in
          *'>'*) printf '%s\t### %s\n' "$kind" "${key#*>}" ;;
          *) printf '%s\t## %s\n' "$kind" "$key" ;;
        esac
      done
    done
    exit 0 ;;
esac
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
    module) find_flat "$scope" 02_modules ;;
    spike) find_flat "$scope" 06_spikes ;;
  esac
}

rewrite_headings() {
  awk -v keys="$2" '
      NR == 1 && $0 == "---" { fm = 1; print; next }
      fm { if ($0 == "---") fm = 0; print; next }
      sdd_fence($0) { print; next }
      sdd_in_fence() { print; next }
      BEGIN { n = split(keys, k, "|"); for (i = 1; i <= n; i++) known[k[i]] = 1 }
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
        parent = sdd_heading_key($0, "## ")
        if (index($0, ":") == 0 && (parent in known)) { print "## " parent ": " parent; count++; next }
      }
      /^### / {
        h = sdd_heading_key($0, "### ")
        if (index($0, ":") == 0 && ((parent ">" h) in known)) { print "### " h ": " h; count++; next }
      }
      { print }
      END { print count + 0 > "/dev/stderr" }
    '"${SDD_AWK_FENCE_FUNCS}${SDD_AWK_HEADING_FUNCS}" "$1"
}

status=0
for kind in $KINDS; do
  eval "keys=\$KEYS_$kind"
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    count="$(rewrite_headings "$file" "$keys" 2>&1 >"$file.tmp")"
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
