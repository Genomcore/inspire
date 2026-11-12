#!/usr/bin/env bash
# expect.sh <case.md> | <repository dir> — the expected record of one case, or of the
# resolution tree, as the spec reader reads it (README.md in this directory gives the
# format). Regenerate with
#   bash expect.sh cases/<name>.md > cases/<name>.json
#   bash expect.sh resolve/repo > resolve/expected.json
# and review the result by hand against CommonMark and ADR D2 before committing it.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$HERE/../../../base/bin/_lib.sh"

# The reader rows as JSON objects; `file` adds the file and the resolved path.
rows() {
  jq -R -s -c --arg file "${2:-}" '
    split("\n") | map(select(. != "") | split("\t")
    | {line: (.[0] | tonumber), form: .[1], target: .[2], text: .[3]}
      + (if $file == "" then {} else {file: $file, resolved: (.[4] // "" | if . == "" then null else . end)} end))' <<< "$1"
}

if [ -d "$1" ]; then
  # A copy outside any git work tree, so `/` resolves from the directory above the KB.
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  cp -R "$1/." "$tmp/"
  cd "$tmp" || exit 1
  SDD_KB_ROOT="inspire_kb"; unset SDD_REPO_ROOT
  files="$(sdd_find_linking)"
  links="$(while IFS= read -r f; do rows "$(sdd_links "$f" wiki)" "$f"; done <<< "$files" | jq -s -c 'add')"
  jq -n --argjson files "$(jq -R -s -c 'split("\n") | map(select(. != ""))' <<< "$files")" \
    --argjson links "$links" '{files: $files, links: $links}'
  exit 0
fi

f="$1"
code="$(LC_ALL=C awk -v codes=1 \
    "$SDD_AWK_LINKS$SDD_AWK_BLOCKS$SDD_AWK_MD_FUNCS$SDD_AWK_SPAN_FUNCS$SDD_AWK_FENCE_FUNCS" "$f" \
  | jq -R -s -c '
  split("\n") | map(select(. != "") | split("\t")
  | {kind: .[0], from: (.[1] | tonumber), to: (.[2] | tonumber)}
    + (if .[0] == "span" then {text: (.[3] | fromjson)} else {} end))')"
jq -n --argjson links "$(rows "$(sdd_links "$f" wiki)")" --argjson code "$code" \
  '{links: $links, code: $code}'
