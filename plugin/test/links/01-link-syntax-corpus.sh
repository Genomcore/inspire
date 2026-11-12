#!/usr/bin/env bash
# The shared link-syntax corpus (adr-markdown-links D2, D4): the spec reader reads
# every case and the resolution tree as their expected files say, and links-resolve
# and the converter's count find the wikilinks outside code the reader finds.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
C="$HERE/fixtures/link-syntax"
RESOLVE="$PLUGIN_ROOT/base/bin/links-resolve.sh"
. "$HERE/lib/assert.sh"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# The wikilinks a file names, one finding per target at its first line, as
# links-resolve reports them: `{line} {target}`.
first_wikis() { jq -r '[.links[] | select(.form == "wiki")]
  | reduce .[] as $w ([]; if any(.[]; .target == $w.target) then . else . + [$w] end)
  | .[] | "\(.line) \(.target)"' "$1"; }
reported_wikis() { jq -r --arg f "$2" 'select(.target == $f) | .message
  | capture("^wikilink \\[\\[(?<t>.*)\\]\\] at line (?<l>[0-9]+):") | "\(.l) \(.t)"' "$1"; }

# One KB holds every case, so links-resolve runs once.
mkdir -p "$T/all/inspire_kb"
cp "$C"/cases/*.md "$T/all/inspire_kb/"
(cd "$T/all" && SDD_KB_ROOT=inspire_kb SDD_SPEC_ROOT=inspire_kb/01_spec bash "$RESOLVE" 2> "$T/findings.jsonl" >/dev/null)

n_cases=0
for md in "$C"/cases/*.md; do
  n="$(basename "$md" .md)"; want="${md%.md}.json"; n_cases=$((n_cases + 1))
  eq "corpus $n: the reader reads it as expected" \
     "$(bash "$C/expect.sh" "$md" | jq -S -c .)" "$(jq -S -c . "$want")"
  eq "corpus $n: links-resolve reports each wikilink the reader finds" \
     "$(reported_wikis "$T/findings.jsonl" "inspire_kb/$n.md")" "$(first_wikis "$want")"

  mkdir -p "$T/$n/inspire_kb"; cp "$md" "$T/$n/inspire_kb/"
  got="$(bash "$PLUGIN_ROOT/scripts/migrate-links.sh" --count --kb "$T/$n/inspire_kb")"
  wikis="$(jq '[.links[] | select(.form == "wiki")] | length' "$want")"
  eq "corpus $n: the converter counts the wikilinks the reader finds" "$got" "$wikis"
done
premise "the corpus holds at least the cases its README promises" "[ $n_cases -ge 50 ]"

# The resolution tree. expect.sh reads it from a copy outside any git work tree, so
# `/` resolves from the directory above the KB (D2's fallback).
eq "resolve: the reader checks the files and resolves the links as expected" \
   "$(bash "$C/expect.sh" "$C/resolve/repo" | jq -S -c .)" "$(jq -S -c . "$C/resolve/expected.json")"
cp -R "$C/resolve/repo" "$T/repo"
(cd "$T/repo" && env -u SDD_REPO_ROOT SDD_KB_ROOT=inspire_kb SDD_SPEC_ROOT=inspire_kb/01_spec \
  bash "$RESOLVE" 2> "$T/resolve.jsonl" >/dev/null)
broken="$(jq -r '.links[] | select(.resolved == null) | "\(.file) \(.target)"' "$C/resolve/expected.json" | LC_ALL=C sort -u)"
reported="$(jq -r '.target + " " + (.message | capture("(\\[\\[(?<w>.*)\\]\\]|\\]\\((?<m>.*)\\) at line)") | .w // .m)' "$T/resolve.jsonl" | LC_ALL=C sort -u)"
eq "resolve: links-resolve reports exactly the links the reader leaves unresolved" "$reported" "$broken"
hasnt "resolve: a template is not checked" "$(cat "$T/resolve.jsonl")" "template"
hasnt "resolve: _migration/ is not checked" "$(cat "$T/resolve.jsonl")" "_migration"

# Under git, `/` resolves from the work tree's root, not from the directory above the KB.
mkdir -p "$T/git/docs" && cp -R "$C/resolve/repo/inspire_kb" "$T/git/docs/" && cp -R "$C/resolve/repo/source" "$T/git/"
git -C "$T/git" init -q
premise "the KB's parent holds no source/" "[ ! -e '$T/git/docs/source' ]"
row="$(cd "$T/git/docs" && env -u SDD_REPO_ROOT SDD_KB_ROOT=inspire_kb bash -c \
  '. "$1/base/bin/_lib.sh"; sdd_links inspire_kb/README.md' _ "$PLUGIN_ROOT" | awk -F'\t' '$3 == "/source/app/main.ts" { print $5 }')"
eq "resolve: under git, a / path joins the work tree root" "$row" "../source/app/main.ts"

summary
