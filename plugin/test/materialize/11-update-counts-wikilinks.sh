#!/usr/bin/env bash
# update changes no link in a concept KB: it counts the wikilinks and points at
# /inspire:migrate (adr-markdown-links D6).
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

# The first released baseline on the concept layout that predates Markdown links.
FIXTURE_WORK="$(mktemp -d)"
# The tag is spelled out: run.sh greps these call sites for what to pre-build.
FIXTURE_BASE="$(fixture_from_tag v0.16.0 "$FIXTURE_WORK" "$REPO")"
proj="$(mktemp -d)/proj"; mkdir -p "$proj" && cp -R "$FIXTURE_BASE/." "$proj/"

note="$proj/inspire_kb/99_tracker/tickets/T-1.md"
mkdir -p "$(dirname "$note")"
printf '# T-1\nTouches [[adr-audit]] and [[billing|the billing module]].\n' > "$note"
premise "the baseline is on the concept layout" "[ -d '$proj/inspire_kb/01_spec' ] && [ ! -d '$proj/inspire_kb/04_domain' ]"
note_before="$(shasum -a 256 "$note" | cut -d' ' -f1)"

out="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype 2>/dev/null)"
n="$(bash "$PLUGIN_ROOT/scripts/migrate-links.sh" --count --kb "$proj/inspire_kb")"
premise "the KB holds wikilinks after the update" "[ '$n' -ge 2 ]"
warning="$(printf '%s' "$out" | jq -r '.warnings[]' | grep 'wikilink')"
has "update: the warning counts every wikilink in the KB" "$warning" "inspire_kb/ holds $n wikilink(s)"
has "update: the warning points at /inspire:migrate" "$warning" "run /inspire:migrate"
eq "update: a file holding wikilinks is left as it was" "$(shasum -a 256 "$note" | cut -d' ' -f1)" "$note_before"

# A KB with no wikilink left gets no warning.
while IFS= read -r f; do
  sed 's/\[\[/[/g; s/\]\]/]/g' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < <(grep -rl '\[\[' "$proj/inspire_kb")
premise "the KB holds no wikilink" "[ \"\$(bash '$PLUGIN_ROOT/scripts/migrate-links.sh' --count --kb '$proj/inspire_kb')\" = 0 ]"
out="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype 2>/dev/null)"
check "update: no wikilink, no warning" "! (printf '%s' \"\$out\" | jq -r '.warnings[]' | grep -q 'wikilink')"

rm -rf "$(dirname "$proj")"
fixture_cleanup "$FIXTURE_WORK"
summary
