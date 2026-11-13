#!/usr/bin/env bash
# visor.sh stages its run inside .inspire/visor/.quartz/: copies of the configuration and
# the plugins, the files whose frontmatter does not parse left out and listed, the port in
# baseUrl. The committed .inspire/visor/ files and inspire_kb/ stay byte-identical.
# Runs on a stubbed host node over a finished install, so no Quartz runs.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$(cd -P "$HERE/.." && pwd -P)"
. "$HERE/lib/assert.sh"
. "$HERE/lib/visor-helpers.sh"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
T="$(cd -P "$T" && pwd -P)"
B="$T/bin"; S="$T/stubs"; mkdir -p "$S"
visor_bin "$B"
stub_node "$S" v22.11.0 "$T/node.log"
P="$S:$B:/usr/bin:/bin"

R="$T/p"; KB="$R/inspire_kb"; Q="$R/.inspire/visor/.quartz"
visor_project "$R"
visor_installed "$R" host
mkdir -p "$KB/99_tracker/tickets" "$KB/x" "$KB/01_spec/_migration"
printf -- '---\nid: T-1\ntitle: Decide: the policy\n---\n\nbody\n' > "$KB/99_tracker/tickets/T-1.md"
printf -- '---\nid: T-2\r\nstatus: Open\r\n---\r\nbody\r\n' > "$KB/99_tracker/tickets/T-2.md"
printf -- '---\nid: [\n---\n' > "$KB/x/odd [1] (copy).md"
printf '# No frontmatter\n\nkey: a: b\n' > "$KB/x/plain.md"
printf -- 'text first\n---\nkey: a: b\n---\n' > "$KB/x/late-dashes.md"
printf -- '---\nid: a: b\n---\n' > "$KB/x/feature.template.md"
printf -- '---\nid: a: b\n---\n' > "$KB/01_spec/_migration/notes.md"
mkdir -p "$Q/plugins/gone"; echo stale > "$Q/plugins/gone/index.js"

premise "yq rejects T-1's frontmatter" \
  "! printf 'id: T-1\ntitle: Decide: the policy\n' | yq '.' >/dev/null 2>&1"
before="$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")"

run_visor "$P" --project-root "$R" --check --port 9090
eq "--check over a finished install: exit 0" "$RC" 0
has "the run reuses the install" "$OUT" "Quartz 5.1.0 is installed"
has "T-1 is listed by its project path with yq's parse error" "$OUT" \
  "  inspire_kb/99_tracker/tickets/T-1.md: yaml: line 2, column "
has "the parse error is yq's own message" "$OUT" ": mapping values are not allowed in this context"
has "a name with glob characters is listed as it is" "$OUT" "  inspire_kb/x/odd [1] (copy).md: yaml:"
hasnt "T-2's CRLF frontmatter parses" "$OUT" "T-2.md"
hasnt "a file that does not open with --- has no frontmatter" "$OUT" "plain.md"
hasnt "a --- after the first line opens no frontmatter" "$OUT" "late-dashes.md"
hasnt "a template the configuration leaves out is not listed" "$OUT" "feature.template.md"
hasnt "a _migration/ file the configuration leaves out is not listed" "$OUT" "notes.md"
has "the summary counts the listed files" "$OUT" "the site builds (2 file(s) left out)"

cfg="$Q/quartz.config.yaml"
eq "the copy's ignorePatterns: the shipped ones, then each failing file, glob characters escaped" \
  "$(yq -r '.configuration.ignorePatterns | join("|")' "$cfg")" \
  "$(yq -r '.configuration.ignorePatterns | join("|")' "$PLUGIN_ROOT/base/visor/quartz.config.yaml")|01_spec/_migration/notes.md|99_tracker/tickets/T-1.md|x/feature.template.md|x/odd \[1\] \(copy\).md"
eq "the copy's baseUrl carries --port" "$(yq -r .configuration.baseUrl "$cfg")" "localhost:9090"
eq "the copy is the committed configuration apart from those two keys" \
  "$(yq -o json 'del(.configuration.ignorePatterns, .configuration.baseUrl)' "$cfg" | jq -cS .)" \
  "$(yq -o json 'del(.configuration.ignorePatterns, .configuration.baseUrl)' "$R/.inspire/visor/quartz.config.yaml" | jq -cS .)"
check "the plugins are copied into the checkout byte for byte" "diff -r '$R/.inspire/visor/plugins' '$Q/plugins'"
check "a plugin dropped from .inspire/visor/plugins/ is gone from the copy" "[ ! -e '$Q/plugins/gone' ]"
has "Quartz installs the plugins of the copied configuration" "$(cat "$T/node.log")" \
  "node quartz/bootstrap-cli.mjs plugin install --from-config"
has "Quartz builds inspire_kb/ in place into .quartz/public" "$(cat "$T/node.log")" \
  "node quartz/bootstrap-cli.mjs build -d $KB -o $Q/public"
hasnt "--check serves nothing" "$(cat "$T/node.log")" "--serve"
eq "the committed .inspire/visor/ files and inspire_kb/ are byte-identical after --check" \
  "$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")" "$before"

: > "$T/node.log"
run_visor "$P" --project-root "$R"
eq "a serve over the stub: exit 0" "$RC" 0
has "a serve names its URL" "$OUT" "serving inspire_kb/ on http://localhost:8080"
has "a serve runs the build with --serve on visor.yaml's port, live reload on the next" \
  "$(cat "$T/node.log")" "build -d $KB -o $Q/public --serve --port 8080 --wsPort 8081"
eq "the copy's baseUrl follows visor.yaml's port" "$(yq -r .configuration.baseUrl "$cfg")" "localhost:8080"
eq "the copy's ignorePatterns do not pile up across runs" \
  "$(yq -r '.configuration.ignorePatterns | length' "$cfg")" \
  "$(( $(yq -r '.configuration.ignorePatterns | length' "$PLUGIN_ROOT/base/visor/quartz.config.yaml") + 4 ))"
eq "the committed .inspire/visor/ files and inspire_kb/ are byte-identical after a serve" \
  "$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")" "$before"

yq -i '.configuration.baseUrl = "kb.example.org"' "$R/.inspire/visor/quartz.config.yaml"
run_visor "$P" --project-root "$R" --check --port 9090
eq "a baseUrl that is not localhost stays as the project set it" \
  "$(yq -r .configuration.baseUrl "$cfg")" "kb.example.org"
summary
