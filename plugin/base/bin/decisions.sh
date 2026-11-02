#!/usr/bin/env bash
# .inspire/bin/decisions.sh
#
# Prints the decision digest: every live ADR's binding statement, read from its
# `## Decision` section. Prints nothing when no ADR is live.
#
# Usage:
#   .inspire/bin/decisions.sh                       # every live decision, in full
#   .inspire/bin/decisions.sh --surface <id>        # only those binding that surface
#   .inspire/bin/decisions.sh --budget <chars>      # past the budget, an index instead

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

SURFACE=""
BUDGET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --surface) SURFACE="${2:-}"; shift 2 ;;
    --budget)  BUDGET="${2:-0}"; shift 2 ;;
    *) echo "decisions.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
case "$BUDGET" in ''|*[!0-9]*) echo "decisions.sh: --budget takes a number of characters" >&2; exit 2 ;; esac

adr_status() {
  grep -m1 '^\*\*Status:\*\*' "$1" 2>/dev/null \
    | sed -E 's/^\*\*Status:\*\*[[:space:]]*//; s/[[:space:]].*$//; s/[^A-Za-z-]//g' \
    | tr '[:upper:]' '[:lower:]'
}

adr_title() {
  awk '
    /^---[[:space:]]*$/ && NR == 1 { fm = 1; next }
    fm { if (/^---[[:space:]]*$/) fm = 0; next }
    /^# / { print substr($0, 3); exit }
  ' "$1"
}

adr_surfaces() {
  head -1 "$1" | grep -q '^---[[:space:]]*$' || return 0
  yq --front-matter=extract '(.surfaces // "") | (select(tag == "!!seq") | join(" ")) // .' \
    "$1" 2>/dev/null || true
}

binds_surface() {
  local surfaces="$1"
  [ -z "$SURFACE" ] || [ -z "$surfaces" ] || [ "$surfaces" = "all" ] && return 0
  case " $surfaces " in *" $SURFACE "*) return 0 ;; esac
  return 1
}

decision_text() {
  sdd_body_section "$1" "Decision" \
    | awk '
        { raw = $0 }
        incomment { if (index($0, "-->")) { $0 = substr($0, index($0, "-->") + 3); incomment = 0 } else next }
        { while ((p = index($0, "<!--")) > 0) {
            q = index(substr($0, p + 4), "-->")
            if (q == 0) { $0 = substr($0, 1, p - 1); incomment = 1; break }
            $0 = substr($0, 1, p - 1) substr($0, p + 4 + q + 2)
          }
          if ($0 ~ /^[[:space:]]*$/ && raw !~ /^[[:space:]]*$/) next
          if ($0 ~ /^[[:space:]]*$/ && n > 0 && lines[n] ~ /^[[:space:]]*$/) next
          lines[++n] = $0 }
        END {
          first = 1; while (first <= n && lines[first] ~ /^[[:space:]]*$/) first++
          last = n;  while (last >= first && lines[last] ~ /^[[:space:]]*$/) last--
          for (i = first; i <= last; i++) print (lines[i] ~ /^[[:space:]]*$/ ? "" : "  " lines[i])
        }
      '
}

FULL=""
INDEX=""
count=0
while IFS= read -r adr; do
  [ -z "$adr" ] && continue
  status="$(adr_status "$adr")"
  case "$status" in superseded|rejected) continue ;; esac
  surfaces="$(adr_surfaces "$adr")"
  binds_surface "$surfaces" || continue
  id="$(basename "$adr" .md)"
  label="${status:-no status}"
  [ -n "$surfaces" ] && [ "$surfaces" != "all" ] && label="${label}; surfaces: ${surfaces// /, }"
  line="- **${id}** (${label}) — $(adr_title "$adr")"
  INDEX="${INDEX}${line}
"
  FULL="${FULL}${line}
$(decision_text "$adr")
"
  count=$((count + 1))
done < <(sdd_find_adrs "$SDD_KB_ROOT/01_adr")

[ "$count" -eq 0 ] && exit 0

scope=""
[ -n "$SURFACE" ] && scope=" that bind the \`${SURFACE}\` surface"
HEAD="INSPIRE decisions — ${count} live ADR(s) in \`inspire_kb/01_adr/\`${scope}. An ADR \
listing surfaces binds only those; one listing none binds the whole suite. Follow each \
one when you specify or build; to change one, use \`/inspire-adr\`. A \`design\` or \
\`prototyped\` decision can still be refined, an \`implemented\` one only superseded. \
The reasons are in each ADR's \`.rationale.md\`."

DIGEST="${HEAD}

${FULL%$'\n'}"
if [ "$BUDGET" -eq 0 ] || [ "${#DIGEST}" -le "$BUDGET" ]; then
  printf '%s\n' "$DIGEST"
  exit 0
fi

TAIL="Their full text is over this digest's budget: read an ADR before you specify or \
build in its area, or run \`.inspire/bin/decisions.sh\` for every decision."
OUT="${HEAD}

${TAIL}
"
shown=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  rest=$((count - shown - 1))
  more=""
  [ "$rest" -gt 0 ] && more="- … and ${rest} more"
  [ "$shown" -eq 0 ] && [ "$rest" -gt 0 ] && more="- … ${count} not listed"
  if [ $(( ${#OUT} + ${#line} + 1 + ${#more} )) -gt "$BUDGET" ]; then
    break
  fi
  OUT="${OUT}
${line}"
  shown=$((shown + 1))
done <<< "$INDEX"
if [ "$shown" -eq 0 ]; then
  OUT="${OUT}
- … ${count} not listed"
elif [ "$shown" -lt "$count" ]; then
  OUT="${OUT}
- … and $((count - shown)) more"
fi
printf '%s\n' "$OUT"
