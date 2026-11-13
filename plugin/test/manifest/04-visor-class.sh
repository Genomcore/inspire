#!/usr/bin/env bash
# The visor payload class (base/visor/ → .inspire/visor/): what a past release
# must not emit, and what a revision carrying the class does emit.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
GEN="$HERE/../scripts/gen-manifest.sh"
. "$HERE/lib/assert.sh"

# 03-reproduction-sweep.sh proves every shipped manifest unchanged; this states
# the directed half for the newest release before the class. The sweep explains
# why `commit` is left out of the comparison.
m="$(mktemp)"; bash "$GEN" --tag v0.17.0 --repo "$REPO" > "$m"
check "premise: v0.17.0 predates the class (no plugin/base/visor in its tree)" \
  "[ \"\$(git -C '$REPO' ls-tree -r --name-only v0.17.0 -- plugin/base/visor | wc -l | tr -d ' ')\" = 0 ]"
check "0.17.0 lists no .inspire/visor paths" \
  "[ \"\$(jq -r '[.files|keys[]|select(startswith(\".inspire/visor/\"))]|length' '$m')\" = 0 ]"
eq "0.17.0's files map is unchanged with visor in the map" \
   "$(jq -cS .files "$m")" "$(jq -cS .files "$HERE/../manifests/0.17.0.json")"
rm -f "$m"

# A synthetic revision keeps the test independent of which tags carry the class.
gsrc="$(mktemp -d)"
mkdir -p "$gsrc/plugin/.claude-plugin" "$gsrc/plugin/base/visor/plugins/inspire/dist" \
         "$gsrc/plugin/base/bin" "$gsrc/plugin/visor-src/inspire-graph"
printf '{"version":"9.9.9","released":"2099-01-01"}\n' > "$gsrc/plugin/.claude-plugin/plugin.json"
printf 'port: 8080\n' > "$gsrc/plugin/base/visor/visor.yaml"
printf '// source\n' > "$gsrc/plugin/visor-src/inspire-graph/build.mjs"
printf 'export {}\n' > "$gsrc/plugin/base/visor/plugins/inspire/dist/index.js"
printf '#!/bin/sh\n' > "$gsrc/plugin/base/bin/x.sh"
( cd "$gsrc" && git init -q && git add -A \
  && git -c user.email=f@f -c user.name=f -c commit.gpgsign=false \
         -c core.hooksPath=/dev/null commit -qm synthetic ) >/dev/null 2>&1
gm="$(mktemp)"; bash "$GEN" --tag HEAD --repo "$gsrc" > "$gm" 2>/dev/null
check "a revision with base/visor/ emits .inspire/visor/visor.yaml" \
  "[ \"\$(jq -r '.files|has(\".inspire/visor/visor.yaml\")' '$gm')\" = true ]"
eq "a nested plugin file keeps its path below .inspire/visor/" \
   "$(jq -r '.files[".inspire/visor/plugins/inspire/dist/index.js"]' "$gm")" \
   "$(git -C "$gsrc" show HEAD:plugin/base/visor/plugins/inspire/dist/index.js | shasum -a 256 | cut -d' ' -f1)"
check "the sibling bin class still lands at .inspire/bin/" \
  "[ \"\$(jq -r '.files|has(\".inspire/bin/x.sh\")' '$gm')\" = true ]"
eq "a visor-carrying revision still reports the 0.3 layout" "$(jq -r .layout "$gm")" "0.3"
check "premise: the synthetic revision tracks plugin/visor-src/" \
  "git -C '$gsrc' cat-file -e HEAD:plugin/visor-src/inspire-graph/build.mjs"
eq "plugin/visor-src/ contributes no manifest path" \
   "$(jq -r '[.files|keys[]|select(endswith("build.mjs"))]|length' "$gm")" "0"
rm -f "$gm"; rm -rf "$gsrc"
summary
