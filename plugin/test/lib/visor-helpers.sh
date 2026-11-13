#!/usr/bin/env bash
# Projects, stubs and a PATH for the tests of plugin/scripts/visor.sh. Sourced after
# assert.sh by the files under plugin/test/visor/; needs PLUGIN_ROOT set.

VISOR_SH="$PLUGIN_ROOT/scripts/visor.sh"

# visor_project DIR [VERSION] — a project the launcher accepts: a lock, a KB with a
# README and one module, and .inspire/visor/ as shipped.
visor_project() {
  local d="$1" v="${2:-0.17.0}"
  mkdir -p "$d/inspire_kb/01_spec/_modules/m" "$d/.inspire"
  printf '{"inspire_version":"%s"}\n' "$v" > "$d/.inspire.lock"
  printf '# KB\n\nSee [m](01_spec/_modules/m/m.module.md).\n' > "$d/inspire_kb/README.md"
  printf -- '---\nid: m\nlifecycle: draft\n---\n\n# m\n\n[KB](../../../README.md)\n' \
    > "$d/inspire_kb/01_spec/_modules/m/m.module.md"
  cp -R "$PLUGIN_ROOT/base/visor" "$d/.inspire/visor"
}

# visor_installed DIR RUNTIME — the stamp of a finished install, so no clone runs.
visor_installed() {
  mkdir -p "$1/.inspire/visor/.quartz"
  printf 'quartz=%s runtime=%s\n' "$(yq -r .quartz "$1/.inspire/visor/visor.yaml")" "$2" \
    > "$1/.inspire/visor/.quartz/.inspire-visor"
}

# visor_bin DIR — wrappers for jq, yq and git only, so PATH=DIR:/usr/bin:/bin reaches
# no node or docker the host has elsewhere (no_host_runtime checks /usr/bin and /bin).
visor_bin() {
  local t
  mkdir -p "$1"
  for t in jq yq git; do
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v "$t")" > "$1/$t"
    chmod +x "$1/$t"
  done
}
no_host_runtime() { [ ! -e /usr/bin/node ] && [ ! -e /bin/node ] && [ ! -e /usr/bin/docker ] && [ ! -e /bin/docker ]; }

# stub_node DIR VERSION LOG [SCAN] — `node --version` prints VERSION; the frontmatter scan
# is logged as `node scan QUARTZ KB` and prints the file SCAN when there is one; any other
# call is logged.
stub_node() {
  printf '#!/bin/sh\n[ "$1" = --version ] && { echo %s; exit 0; }
[ "$1" = --input-type=module ] && { echo "node scan $4 $5" >> "%s"; cat "%s" 2>/dev/null; exit 0; }
echo "node $*" >> "%s"\nexit 0\n' "$2" "$3" "${4:-/dev/null}" "$3" > "$1/node"
  chmod +x "$1/node"
}

# stub_npm DIR — an npm on PATH, which the host runtime needs beside node.
stub_npm() {
  printf '#!/bin/sh\nexit 0\n' > "$1/npm"
  chmod +x "$1/npm"
}

# port_open PORT — whether something accepts connections on 127.0.0.1:PORT.
port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

# free_port — a port N such that nothing listens on N or N+1.
free_port() {
  local p=$((20000 + RANDOM % 20000))
  while port_open "$p" || port_open $((p + 1)); do p=$((p + 2)); done
  echo "$p"
}

# stub_docker DIR LOG [PS] — answers `docker info`, and `docker ps` with PS; logs every
# other call on one line (the scan's script up to its first newline).
stub_docker() {
  printf '#!/bin/sh\n[ "$1" = info ] && exit 0\n[ "$1" = ps ] && { echo %s; exit 0; }
echo "docker $*" | head -n 1 >> "%s"\nexit 0\n' "${3:-}" "$2" > "$1/docker"
  chmod +x "$1/docker"
}

# stub_git_fail DIR — a git whose clone fails, which ends a run at the install (exit 3).
stub_git_fail() {
  printf '#!/bin/sh\necho "fatal: offline" >&2\nexit 128\n' > "$1/git"
  chmod +x "$1/git"
}

# run_visor PATH ARGS... — runs the launcher under PATH; sets OUT (stdout+stderr) and RC.
run_visor() {
  local p="$1"; shift
  OUT="$(PATH="$p" /bin/bash "$VISOR_SH" "$@" 2>&1)"; RC=$?
}

# tree_sum DIR — one line per file under DIR, .quartz/ left out: path and content hash.
tree_sum() {
  (cd "$1" && find . -path ./.quartz -prune -o -type f -print | LC_ALL=C sort \
    | while IFS= read -r f; do printf '%s %s\n' "$(cksum < "$f")" "$f"; done)
}
