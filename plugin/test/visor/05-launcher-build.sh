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
N=9
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
mkdir -p "$KB/99_tracker/tickets"
printf -- '---\nid: T-1\ntitle: Decide: the policy\n---\n\nbody\n' > "$KB/99_tracker/tickets/T-1.md"
before="$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")"

OUT="$(/bin/bash "$VISOR_SH" --project-root "$R" --check 2>&1)"; RC=$?
if [ "$RC" -eq 3 ]; then
  skipped "$N" "a real --check build (the Quartz install failed: $(printf '%s' "$OUT" | tail -n 2 | tr '\n' ' '))"
  summary
fi
eq "a real --check over a small KB: exit 0" "$RC" 0
has "the file whose frontmatter does not parse is listed" "$OUT" "  inspire_kb/99_tracker/tickets/T-1.md: yaml:"
check "the site holds the module's page" "[ -f '$PUB/01_spec/_modules/m/m.module.html' ]"
check "the site holds no page for the listed file" "[ ! -e '$PUB/99_tracker/tickets/T-1.html' ]"
check "the site root redirects to the KB's README" "grep -q 'url=./readme' '$PUB/index.html'"
check "the module page carries the visor's graph" "grep -q 'data-quartz-plugin=\"inspire-graph\"' '$PUB/01_spec/_modules/m/m.module.html'"
check "no node_modules lands in the committed plugins" "[ -z \"\$(find '$R/.inspire/visor/plugins' -name node_modules)\" ]"
eq "the committed .inspire/visor/ files and inspire_kb/ are byte-identical after a real build" \
  "$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")" "$before"
OUT="$(/bin/bash "$VISOR_SH" --project-root "$R" --check 2>&1)"
has "a second run reuses the install" "$OUT" "Quartz $QV is installed"
summary
