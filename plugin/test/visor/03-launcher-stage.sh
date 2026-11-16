#!/usr/bin/env bash
# visor.sh stages its run inside .inspire/visor/.quartz/: copies of the configuration and
# the plugins, the files the frontmatter scan lists left out and listed, the port in
# baseUrl. The committed .inspire/visor/ files and inspire_kb/ stay byte-identical.
# Runs on a stubbed host node over a finished install, so no Quartz runs; the stub's scan
# prints a fixed answer (05 runs the real scan).
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$(cd -P "$HERE/.." && pwd -P)"
. "$HERE/lib/assert.sh"
. "$HERE/lib/visor-helpers.sh"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
T="$(cd -P "$T" && pwd -P)"
B="$T/bin"; S="$T/stubs"; mkdir -p "$S"
visor_bin "$B"
stub_node "$S" v22.11.0 "$T/node.log" "$T/scan.out"
stub_npm "$S"
P="$S:$B:/usr/bin:/bin"
printf '%s\n' '{"path":"99_tracker/tickets/T-1.md","error":"duplicated mapping key (3:1)"}' \
  '{"path":"x/odd [1] (copy).md","error":"unexpected end of the stream (3:1)"}' > "$T/scan.out"

R="$T/p"; KB="$R/inspire_kb"; Q="$R/.inspire/visor/.quartz"
visor_project "$R"
visor_installed "$R" host
FP="$(free_port)"
yq -i ".port = $FP" "$R/.inspire/visor/visor.yaml"
mkdir -p "$Q/plugins/gone"; echo stale > "$Q/plugins/gone/index.js"
before="$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")"

run_visor "$P" --project-root "$R" --check --port 9090
eq "--check over a finished install: exit 0" "$RC" 0
has "the run reuses the install" "$OUT" "Quartz 5.1.0 is installed"
has "the scan reads inspire_kb/ with the checkout's packages" "$(cat "$T/node.log")" "node scan $Q $KB"
has "each listed file is named by its project path, with the scan's error" "$OUT" \
  "  inspire_kb/99_tracker/tickets/T-1.md: duplicated mapping key (3:1)"
has "a name with glob characters is listed as it is" "$OUT" "  inspire_kb/x/odd [1] (copy).md: unexpected"
has "the summary counts the listed files" "$OUT" "the site builds (2 file(s) left out)"

cfg="$Q/quartz.config.yaml"
eq "the copy's ignorePatterns: the shipped ones, then each failing file, glob characters escaped" \
  "$(yq -r '.configuration.ignorePatterns | join("|")' "$cfg")" \
  "$(yq -r '.configuration.ignorePatterns | join("|")' "$PLUGIN_ROOT/base/visor/quartz.config.yaml")|99_tracker/tickets/T-1.md|x/odd \[1\] \(copy\).md"
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
has "a serve names its URL" "$OUT" "serving inspire_kb/ on http://localhost:$FP"
has "a serve runs the build with --serve on visor.yaml's port, live reload on the next" \
  "$(cat "$T/node.log")" "build -d $KB -o $Q/public --serve --port $FP --wsPort $((FP + 1))"
eq "the copy's baseUrl follows visor.yaml's port" "$(yq -r .configuration.baseUrl "$cfg")" "localhost:$FP"
eq "the copy's ignorePatterns do not pile up across runs" \
  "$(yq -r '.configuration.ignorePatterns | length' "$cfg")" \
  "$(( $(yq -r '.configuration.ignorePatterns | length' "$PLUGIN_ROOT/base/visor/quartz.config.yaml") + 2 ))"
eq "the committed .inspire/visor/ files and inspire_kb/ are byte-identical after a serve" \
  "$(tree_sum "$R/.inspire/visor")$(tree_sum "$KB")" "$before"

: > "$T/scan.out"
run_visor "$P" --project-root "$R" --check --port 010
eq "a port with a leading zero reads as decimal: --port 010 is port 10" \
  "$(yq -r .configuration.baseUrl "$cfg")" "localhost:10"
hasnt "a scan that lists nothing prints no listing" "$OUT" "left out of the site"
has "a scan that lists nothing: the summary says 0" "$OUT" "the site builds (0 file(s) left out)"

yq -i '.configuration.baseUrl = "kb.example.org"' "$R/.inspire/visor/quartz.config.yaml"
run_visor "$P" --project-root "$R" --check --port 9090
eq "a baseUrl that is not localhost stays as the project set it" \
  "$(yq -r .configuration.baseUrl "$cfg")" "kb.example.org"

# --- a scan that fails --------------------------------------------------------
printf '#!/bin/sh\n[ "$1" = --version ] && { echo v22.11.0; exit 0; }\n[ "$1" = --input-type=module ] && { echo "Cannot find package gray-matter" >&2; exit 1; }\nexit 0\n' \
  > "$S/node"
run_visor "$P" --project-root "$R" --check
eq "a scan that fails: exit 2" "$RC" 2
has "a scan that fails: its error is relayed" "$OUT" "the frontmatter scan failed:
Cannot find package gray-matter"
summary
