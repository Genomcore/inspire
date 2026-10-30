#!/usr/bin/env bash
# .inspire/bin/adr-split.sh
#
# Splits a single-file ADR into its decision `adr-{slug}.md` and its rationale
# `adr-{slug}.rationale.md`, moving every line verbatim.
#
# Usage:
#   .inspire/bin/adr-split.sh --list [path...]   # print the single-file ADRs, write nothing
#   .inspire/bin/adr-split.sh [path...]          # split them

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

MODE="split"
if [ "${1:-}" = "--list" ]; then
  MODE="list"
  shift
fi
[ $# -eq 0 ] && set -- "$SDD_KB_ROOT/01_adr"

is_single_file() {
  local file="$1"
  [ -f "${file%.md}.rationale.md" ] && return 1
  ! grep -q '^\*\*Rationale:\*\*' "$file"
}

has_decision_section() {
  awk '
    /^(```|~~~)/ { fence = !fence; next }
    !fence && /<!--/ && !/-->/ { incomment = 1; next }
    incomment { if (/-->/) incomment = 0; next }
    !fence && /^## Decision[[:space:]]*$/ { found = 1; exit }
    END { exit !found }
  ' "$1"
}

split_adr() {
  local file="$1" slug rationale
  slug="$(basename "$file" .md)"
  rationale="${file%.md}.rationale.md"

  awk -v slug="$slug" -v dec_out="$file.tmp" -v rat_out="$rationale.tmp" '
    function flush(out, n, arr,    i, last) {
      last = n
      while (last > 0 && arr[last] ~ /^[[:space:]]*$/) last--
      for (i = 1; i <= last; i++) print arr[i] > out
    }
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; pre[++np] = $0; next }
    infm { pre[++np] = $0; if (/^---[[:space:]]*$/) infm = 0; next }
    {
      if (/^(```|~~~)/) fence = !fence
      if (incomment) { if (/-->/) incomment = 0 }
      else if (!fence && /<!--/ && !/-->/) incomment = 1
      else if (!fence && /^## /) {
        section = ($0 ~ /^## Decision[[:space:]]*$/) ? "dec" : "rat"
        started = 1
      }
    }
    !started {
      pre[++np] = $0
      if (!incomment && !fence) {
        if (title == "" && /^# /) { title = substr($0, 3); h1 = np }
        if (/^\*\*[^*]+:\*\*/ || /^Supersedes:/) lastmeta = np
      }
      next
    }
    section == "dec" { dec[++nd] = $0; next }
    { rat[++nr] = $0 }
    END {
      anchor = lastmeta ? lastmeta : (h1 ? h1 : np)
      for (i = 1; i <= np; i++) {
        out[++no] = pre[i]
        if (i == anchor) {
          if (!lastmeta) out[++no] = ""
          out[++no] = "**Rationale:** [[" slug ".rationale]]"
        }
      }
      while (no > 0 && out[no] ~ /^[[:space:]]*$/) no--
      out[++no] = ""
      for (i = 1; i <= nd; i++) out[++no] = dec[i]
      flush(dec_out, no, out)

      head[1] = "# " title " — rationale"
      head[2] = ""
      head[3] = "**Decision:** [[" slug "]]"
      head[4] = ""
      nh = 4
      for (i = 1; i <= nr; i++) head[++nh] = rat[i]
      flush(rat_out, nh, head)
    }
  ' "$file" || return 1

  mv "$file.tmp" "$file"
  mv "$rationale.tmp" "$rationale"
}

status=0
while IFS= read -r adr; do
  [ -z "$adr" ] && continue
  is_single_file "$adr" || continue
  if [ "$MODE" = "list" ]; then
    printf '%s\n' "$adr"
    continue
  fi
  if ! has_decision_section "$adr"; then
    printf 'skipped\t%s\tno ## Decision section to keep in the decision file\n' "$adr"
    status=1
    continue
  fi
  if split_adr "$adr"; then
    printf 'split\t%s\t%s\n' "$adr" "${adr%.md}.rationale.md"
  else
    rm -f "$adr.tmp" "${adr%.md}.rationale.md.tmp"
    printf 'failed\t%s\n' "$adr"
    status=1
  fi
done < <(for scope in "$@"; do sdd_find_adrs "$scope"; done)

exit "$status"
