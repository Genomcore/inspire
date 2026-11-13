#!/usr/bin/env bash
# The visor's graph plugin: the copy shipped under base/visor/plugins/inspire-graph/
# against its source in visor-src/, and against a fresh build when Node 22+ is present.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$(cd -P "$HERE/.." && pwd -P)"
. "$HERE/lib/assert.sh"

SRC="$PLUGIN_ROOT/visor-src/inspire-graph"
VB="$PLUGIN_ROOT/base/visor"
GB="$VB/plugins/inspire-graph"
PKG="$GB/package.json"

# --- the shipped copy ------------------------------------------------------
eq "the shipped copy is package.json, LICENSE and dist/index.js only" \
   "$(cd "$GB" && find . -type f | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ' ')" \
   "LICENSE dist/index.js package.json "
eq "its package.json is the source's without scripts and devDependencies" \
   "$(jq -cS . "$PKG")" "$(jq -cS 'del(.scripts, .devDependencies)' "$SRC/package.json")"
# Quartz names a local plugin after its directory and registers its component under
# that name, so the package, its manifest and the directory agree.
eq "the package and its manifest are named after the directory" \
   "$(jq -r '.name + " " + .quartz.name' "$PKG")" "inspire-graph inspire-graph"
eq "the manifest declares a component plugin" "$(jq -r .quartz.category "$PKG")" "component"
check "the manifest names the Graph component" "jq -e '.quartz.components.Graph' '$PKG' >/dev/null"
eq "its quartzVersion range is the inspire plugin's" \
   "$(jq -r .quartz.quartzVersion "$PKG")" "$(jq -r .quartz.quartzVersion "$VB/plugins/inspire/package.json")"
eq "both entry points resolve to the shipped dist/index.js" \
   "$(jq -r '[.exports["."].import, .exports["./components"].import] | join(" ")' "$PKG")" \
   "./dist/index.js ./dist/index.js"
check "preact is a peer dependency, which Quartz links to its own copy" \
  "jq -e '.peerDependencies.preact' '$PKG' >/dev/null"
check "dist imports preact and bundles none of it" \
  "grep -q 'from \"preact/jsx-runtime\"' '$GB/dist/index.js' && ! grep -q 'prototype.setState' '$GB/dist/index.js'"
check "dist is unminified: the colour and legend functions keep their names" \
  "grep -q 'function nodeColor(' '$GB/dist/index.js' && grep -q 'function renderLegend(' '$GB/dist/index.js'"
check "LICENSE is upstream's MIT licence, as in the source" \
  "grep -q '^MIT License' '$GB/LICENSE' && cmp -s '$GB/LICENSE' '$SRC/LICENSE'"
eq "the package names its origin, quartz-community/graph" \
   "$(jq -r .repository.url "$PKG")" "https://github.com/quartz-community/graph"
# git's output is captured under && so a git that cannot run fails the check.
check "no node_modules lies under base/ or is tracked under plugin/" \
  "[ -z \"\$(find '$PLUGIN_ROOT/base' -name node_modules)\" ] \
   && tracked=\"\$(git -C '$PLUGIN_ROOT' ls-files -- .)\" && [ -n \"\$tracked\" ] \
   && ! printf '%s\n' \"\$tracked\" | grep -q node_modules"
eq "the configuration enables ./plugins/inspire-graph and disables Quartz's graph" \
   "$(yq -r '[.plugins[] | select(.source == "./plugins/inspire-graph" or .source == "@quartz-community/graph") | .source + "=" + (.enabled | tostring)] | join(" ")' "$VB/quartz.config.yaml")" \
   "@quartz-community/graph=false ./plugins/inspire-graph=true"

# --- a fresh build ---------------------------------------------------------
LABEL="a fresh build of visor-src/inspire-graph equals the shipped copy"
major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if command -v npm >/dev/null 2>&1 && [ "$major" -ge 22 ] 2>/dev/null; then
  out="$(mktemp -d)"
  bash "$PLUGIN_ROOT/scripts/build-visor-graph.sh" --out "$out/graph" >"$out/log" 2>&1
  case $? in
    0) check "$LABEL" "diff -r '$out/graph' '$GB' >/dev/null" ;;
    3) skip "$LABEL (npm ci failed: offline with a cold npm cache)" ;;
    *) bad "$LABEL (the build failed: $(tail -n 3 "$out/log" | tr '\n' ' '))" ;;
  esac

  # Exit 3 is the skip above, so it must mean a network failure and nothing else. The
  # script runs from a copy laid out as in plugin/, with the source changed in place.
  copy_build() {
    rm -rf "$out/copy"; mkdir -p "$out/copy/scripts" "$out/copy/visor-src/inspire-graph"
    cp "$PLUGIN_ROOT/scripts/build-visor-graph.sh" "$out/copy/scripts/"
    ( cd "$SRC" && tar cf - --exclude node_modules --exclude dist . ) \
      | ( cd "$out/copy/visor-src/inspire-graph" && tar xf - )
  }
  copy_build
  jq '.devDependencies["left-pad"] = "1.3.0"' "$SRC/package.json" > "$out/copy/visor-src/inspire-graph/package.json"
  bash "$out/copy/scripts/build-visor-graph.sh" --out "$out/o" >"$out/log" 2>&1
  eq "a lock out of step with package.json fails the build: exit 1, not the offline skip" "$?" "1"
  copy_build
  npm_config_cache="$out/cache" npm_config_registry="http://127.0.0.1:9/" npm_config_fetch_retries=0 \
    bash "$out/copy/scripts/build-visor-graph.sh" --out "$out/o" >"$out/log" 2>&1
  eq "an unreachable registry with a cold npm cache exits 3, the offline skip" "$?" "3"
  rm -rf "$out"
else
  skip "$LABEL (no Node 22 or later with npm)"
  skipped 2 "the build's exit for a broken lock and for no network (no Node 22 or later with npm)"
fi
summary
