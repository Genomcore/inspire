#!/usr/bin/env bash
# visor.sh --check for real: Quartz installed from its tag and a small KB built, when the
# host has Node 22 or later and reaches GitHub; otherwise a recorded SKIP. The shipped
# settings the launcher reads are checked either way.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$(cd -P "$HERE/.." && pwd -P)"
. "$HERE/lib/assert.sh"
. "$HERE/lib/visor-helpers.sh"

VB="$PLUGIN_ROOT/base/visor"
QV="$(yq -r .quartz "$VB/visor.yaml")"

# --- the shipped settings --------------------------------------------------
check "visor.yaml's quartz is a version X.Y.Z" "printf '%s' '$QV' | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'"
check "visor.yaml's node_image pins a Node 22 tag" \
  "yq -r .node_image '$VB/visor.yaml' | grep -Eq '^node:22\.[0-9]+\.[0-9]+'"
check "quartz.config.yaml's baseUrl is localhost, which the launcher sets to the port it serves on" \
  "yq -r .configuration.baseUrl '$VB/quartz.config.yaml' | grep -Eqx 'localhost(:[0-9]+)?'"
eq "every shipped plugin declares a quartzVersion" \
  "$(for d in "$VB"/plugins/*/; do jq -r '.quartz.quartzVersion // "MISSING"' "$d/package.json"; done | grep -c MISSING)" "0"

# --- a real build ----------------------------------------------------------
premise "yq rejects T-1's frontmatter" \
  "! printf 'id: T-1\ntitle: Decide: the policy\n' | yq '.' >/dev/null 2>&1"
premise "yq accepts T-3's duplicate key, which Quartz refuses" "printf 'id: T-3\nid: T-3b\n' | yq '.' >/dev/null 2>&1"
N=23
major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if ! command -v npm >/dev/null 2>&1 || ! [ "$major" -ge 22 ] 2>/dev/null; then
  skipped "$N" "a real --check build (no Node 22 or later with npm)"
  summary
fi
if ! git ls-remote --exit-code https://github.com/jackyzha0/quartz.git "refs/tags/v$QV" >/dev/null 2>&1; then
  skipped "$N" "a real --check build (Quartz's repository is out of reach)"
  summary
fi

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
T="$(cd -P "$T" && pwd -P)"
R="$T/p"; KB="$R/inspire_kb"; PUB="$R/.inspire/visor/.quartz/public"
visor_project "$R"
mkdir -p "$KB/99_tracker/tickets" "$KB/x" "$KB/01_spec/_migration"
printf -- '---\nid: T-1\ntitle: Decide: the policy\n---\n\nbody\n' > "$KB/99_tracker/tickets/T-1.md"
printf -- '---\nid: T-2\r\nstatus: Open\r\n---\r\nbody\r\n' > "$KB/99_tracker/tickets/T-2.md"
printf -- '---\nid: T-3\nid: T-3b\n---\n\nbody\n' > "$KB/99_tracker/tickets/T-3.md"
printf -- '---\n- a\n- b\n---\n\nbody\n' > "$KB/x/list.md"
printf -- '---\nid: [\n---\n' > "$KB/x/odd [1] (copy).md"
printf -- '---\nid: four\n----\n\n# body: a: b\n' > "$KB/x/four-dashes.md"
printf '# No frontmatter\n\nkey: a: b\n' > "$KB/x/plain.md"
printf -- 'text first\n---\nkey: a: b\n---\n' > "$KB/x/late-dashes.md"
printf -- '---\nid: a: b\n---\n' > "$KB/x/feature.template.md"
printf -- '---\nid: a: b\n---\n' > "$KB/01_spec/_migration/notes.md"
before="$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")"

OUT="$(/bin/bash "$VISOR_SH" --project-root "$R" --check 2>&1)"; RC=$?
# Only the network steps of the install may skip; a failure of the launcher's own staging fails.
case "$RC:$OUT" in
  3:*"git clone of Quartz"*|3:*"npm ci in .inspire/visor/.quartz/ failed"*)
    skipped "$N" "a real --check build (the Quartz install failed: $(printf '%s' "$OUT" | tail -n 2 | tr '\n' ' '))"
    summary ;;
esac
eq "a real --check over a small KB: exit 0" "$RC" 0
has "the file whose frontmatter does not parse is listed" "$OUT" "  inspire_kb/99_tracker/tickets/T-1.md: "
has "T-1 is listed by its project path with the parser's error" "$OUT" \
  "  inspire_kb/99_tracker/tickets/T-1.md: bad indentation of a mapping entry"
has "the parse error's position counts lines in the file, not in the frontmatter" "$OUT" "T-1.md: bad indentation of a mapping entry (3:14)"
has "a duplicate key is listed, as Quartz refuses it" "$OUT" \
  "  inspire_kb/99_tracker/tickets/T-3.md: duplicated mapping key (3:1)"
has "a frontmatter that is a list is listed" "$OUT" "  inspire_kb/x/list.md: Invalid frontmatter: expected properties"
has "a name with glob characters is listed as it is" "$OUT" "  inspire_kb/x/odd [1] (copy).md: "
hasnt "T-2's CRLF frontmatter parses" "$OUT" "T-2.md"
hasnt "a frontmatter closed by ---- parses, as gray-matter closes it there" "$OUT" "four-dashes.md"
hasnt "a file that does not open with --- has no frontmatter" "$OUT" "plain.md"
hasnt "a --- after the first line opens no frontmatter" "$OUT" "late-dashes.md"
hasnt "a template the configuration leaves out is not listed" "$OUT" "feature.template.md"
hasnt "a _migration/ file the configuration leaves out is not listed" "$OUT" "notes.md"
has "the summary counts the listed files" "$OUT" "the site builds (4 file(s) left out)"
check "the site holds the module's page" "[ -f '$PUB/01_spec/_modules/m/m.module.html' ]"
check "the site holds no page for the listed file" "[ ! -e '$PUB/99_tracker/tickets/T-1.html' ]"
check "the site holds no page for the duplicate-key ticket" "[ ! -e '$PUB/99_tracker/tickets/T-3.html' ]"
check "the site holds the page closed by ----" "[ -f '$PUB/x/four-dashes.html' ]"
check "the site root redirects to the KB's README" "grep -q 'url=./readme' '$PUB/index.html'"
check "the module page carries the visor's graph" "grep -q 'data-quartz-plugin=\"inspire-graph\"' '$PUB/01_spec/_modules/m/m.module.html'"
check "no node_modules lands in the committed plugins" "[ -z \"\$(find '$R/.inspire/visor/plugins' -name node_modules)\" ]"
eq "the committed .inspire/visor/ files and inspire_kb/ are byte-identical after a real build" \
  "$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")" "$before"
OUT="$(/bin/bash "$VISOR_SH" --project-root "$R" --check 2>&1)"
has "a second run reuses the install" "$OUT" "Quartz $QV is installed"
summary
