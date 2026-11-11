#!/usr/bin/env bash
# .inspire/bin/decisions.sh
#
# Prints the decision digest: every live ADR's binding statement, read from its
# `## Decision` section. Prints nothing when no ADR is live.
#
# Usage:
#   .inspire/bin/decisions.sh                       # every live decision, in full
#   .inspire/bin/decisions.sh --face <id>           # only those binding that face
#
# An ADR binds a face when it lists it under `faces:`, when it sits in that face's
# `_adr/`, or when it lists neither `faces:` nor `bundles:`. An ADR in a module's
# `_adr/` binds every face.
#   .inspire/bin/decisions.sh --budget <chars>      # past the budget, an index instead

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

FACE=""
BUDGET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --face)    FACE="${2:-}"; shift 2 ;;
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

# adr_list <file> <field> — a frontmatter list (`faces:` or `bundles:`), space-joined.
adr_list() {
  head -1 "$1" | grep -q '^---[[:space:]]*$' || return 0
  yq --front-matter=extract "(.$2 // \"\") | (select(tag == \"!!seq\") | join(\" \")) // ." \
    "$1" 2>/dev/null || true
}

# adr_placement <file> — `face {f}` or `module {m}` when the ADR sits in a face's or a
# module's `_adr/`; empty for a global one.
adr_placement() {
  case "$1" in
    */_faces/*/_adr/*)   local r="${1#*/_faces/}";   printf 'face %s\n' "${r%%/*}" ;;
    */_modules/*/_adr/*) local r="${1#*/_modules/}"; printf 'module %s\n' "${r%%/*}" ;;
  esac
}

binds_face() {
  local faces="$1" bundles="$2" placement="$3"
  [ -z "$FACE" ] && return 0
  case "$placement" in
    "face $FACE") return 0 ;;
    face\ *)      return 1 ;;
    module\ *)    return 0 ;;
  esac
  [ -z "$faces" ] && [ -z "$bundles" ] && return 0
  case " $faces " in *" $FACE "*) return 0 ;; esac
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
  faces="$(adr_list "$adr" faces)"
  bundles="$(adr_list "$adr" bundles)"
  placement="$(adr_placement "$adr")"
  binds_face "$faces" "$bundles" "$placement" || continue
  id="$(sdd_artifact_id "$adr")"
  label="${status:-no status}"
  [ -n "$placement" ] && label="${label}; ${placement% *}: ${placement#* }"
  [ -n "$faces" ] && label="${label}; faces: ${faces// /, }"
  [ -n "$bundles" ] && label="${label}; bundles: ${bundles// /, }"
  line="- **${id}** (${label}) — $(adr_title "$adr")"
  INDEX="${INDEX}${line}
"
  FULL="${FULL}${line}
$(decision_text "$adr")
"
  count=$((count + 1))
done < <(sdd_find_adrs "$SDD_SPEC_ROOT")

[ "$count" -eq 0 ] && exit 0

scope=""
[ -n "$FACE" ] && scope=" that bind the \`${FACE}\` face"
HEAD="INSPIRE decisions — ${count} live ADR(s) in \`inspire_kb/01_spec/\`${scope}. An ADR \
listing faces binds only those; one listing none binds the whole project. Follow each \
one when you specify or build; to change one, use \`/inspire-adr\`. A \`design\` or \
\`prototyped\` decision can still be refined, an \`implemented\` one only superseded. \
The reasons are in each ADR's \`.adr.rationale.md\`."

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
