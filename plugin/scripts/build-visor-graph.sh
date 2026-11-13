#!/usr/bin/env bash
# Maintainer tool: rebuild the visor's graph plugin from its source.
#
#   build-visor-graph.sh [--out DIR]
#
# Reads plugin/visor-src/inspire-graph/ and writes package.json, LICENSE and
# dist/index.js to plugin/base/visor/plugins/inspire-graph/, or to DIR. Needs Node 22
# or later with npm. The dependencies install into a temporary copy of the source, so
# no node_modules is ever written inside the repository.
#
# Exit codes: 0 built · 1 build failed · 2 usage or no Node 22+ · 3 npm ci failed
# (offline with a cold npm cache, typically).
set -euo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
SRC="$HERE/../visor-src/inspire-graph"
OUT="$HERE/../base/visor/plugins/inspire-graph"

die() { echo "build-visor-graph.sh: $2" >&2; exit "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --out)   [ $# -ge 2 ] || die 2 "--out needs a directory"; OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *)       die 2 "unknown argument $1" ;;
  esac
done

command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 \
  || die 2 "node and npm are required"
major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$major" -ge 22 ] || die 2 "Node 22 or later is required (found $(node --version))"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
( cd "$SRC" && tar cf - --exclude node_modules --exclude dist . ) | ( cd "$work" && tar xf - )

( cd "$work" && npm ci --ignore-scripts --no-audit --no-fund --prefer-offline ) >"$work/npm.log" 2>&1 \
  || { cat "$work/npm.log" >&2; die 3 "npm ci failed"; }
( cd "$work" && node build.mjs ) || die 1 "the build failed"

# Only the three shipped entries are replaced, so a mistyped --out deletes nothing else.
mkdir -p "$OUT"
rm -rf "$OUT/dist" "$OUT/package.json" "$OUT/LICENSE"
mkdir -p "$OUT/dist"
cp "$work/dist/index.js" "$OUT/dist/index.js"
cp "$work/LICENSE" "$OUT/LICENSE"
jq 'del(.scripts, .devDependencies)' "$work/package.json" > "$OUT/package.json"
