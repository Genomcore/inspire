#!/usr/bin/env bash
#
# plugin/scripts/visor.sh — the launcher behind /inspire:visor. It checks the project,
# installs Quartz under .inspire/visor/.quartz/, and builds and serves inspire_kb/ with
# the configuration and plugins of .inspire/visor/.
#
# Usage:
#   visor.sh --project-root PATH   # repo root
#            [--port N]            # default: port in .inspire/visor/visor.yaml
#            [--check]             # every check and the build; serves nothing
#
# It writes only under .inspire/visor/.quartz/: the committed files of .inspire/visor/
# and every file under inspire_kb/ stay as they are.
#
# stderr: progress, refusals, and the files left out of the site.
# exit:   0 ok · 1 refusal (a check failed) · 2 the build failed · 3 the Quartz install failed
#
# Prerequisites: bash 3.2+, jq, yq (Mike Farah's v4), git; Node 22 or later with npm, or
# Docker. It passes visor-scan.mjs and visor-loopback.mjs, beside it, to Node.

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
LOCK_FLOOR="0.17.0"
NODE_MIN=22
QUARTZ_REPO="https://github.com/jackyzha0/quartz.git"
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

log() { printf '%s\n' "$*" >&2; }
refuse() { log "visor.sh: $*"; exit 1; }

usage() {
  cat >&2 <<'EOF'
Usage: visor.sh --project-root PATH [--port N] [--check]
EOF
}

ROOT=""
PORT=""
CHECK=0

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project-root)
        [ "$#" -ge 2 ] || { log "visor.sh: --project-root requires a value"; usage; exit 1; }
        ROOT="$2"; shift 2 ;;
      --port)
        [ "$#" -ge 2 ] || { log "visor.sh: --port requires a value"; usage; exit 1; }
        PORT="$2"; shift 2 ;;
      --check)
        CHECK=1; shift 1 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        log "visor.sh: unknown flag '$1'"; usage; exit 1 ;;
    esac
  done
  [ -n "$ROOT" ] || { log "visor.sh: --project-root is required"; usage; exit 1; }
  [ -d "$ROOT" ] || refuse "--project-root '$ROOT' is not a directory"
  ROOT="$(cd -P "$ROOT" && pwd -P)"
  command -v jq >/dev/null 2>&1 || refuse "jq is required on PATH"
  command -v yq >/dev/null 2>&1 || refuse "yq is required on PATH"
}

# ver_cmp A B — prints -1, 0 or 1; both are X.Y.Z.
ver_cmp() {
  local IFS=. a b i
  a=($1); b=($2)
  for i in 0 1 2; do
    [ "${a[$i]}" -lt "${b[$i]}" ] && { echo -1; return; }
    [ "${a[$i]}" -gt "${b[$i]}" ] && { echo 1; return; }
  done
  echo 0
}

# in_range VERSION RANGE — 0 inside, 1 outside, 2 unreadable. A range is one or more
# space-separated comparators (>=, <=, >, <, = or none, then X.Y.Z), all of which hold.
in_range() {
  local v="$1" c cmp n=0 parts ops=() vers=()
  local re='^(>=|<=|>|<|=)?([0-9]+\.[0-9]+\.[0-9]+)$'
  read -r -a parts <<< "$2"
  for c in ${parts[@]+"${parts[@]}"}; do
    [[ $c =~ $re ]] || return 2
    ops[$n]="${BASH_REMATCH[1]:-=}"; vers[$n]="${BASH_REMATCH[2]}"; n=$((n + 1))
  done
  [ "$n" -gt 0 ] || return 2
  while [ "$n" -gt 0 ]; do
    n=$((n - 1)); cmp="$(ver_cmp "$v" "${vers[$n]}")"
    case "${ops[$n]}$cmp" in
      '>=0'|'>=1'|'<=0'|'<=-1'|'>1'|'<-1'|'=0') ;;
      *) return 1 ;;
    esac
  done
  return 0
}

check_lock() {
  local lock="$ROOT/.inspire.lock" v
  local fix="Run /inspire:update, then /inspire:migrate."
  [ -f "$lock" ] || refuse "the visor needs INSPIRE $LOCK_FLOOR or later, and this project has no .inspire.lock. $fix"
  v="$(jq -r '.inspire_version // empty' "$lock" 2>/dev/null)"
  [ -n "$v" ] || refuse "the visor needs INSPIRE $LOCK_FLOOR or later, and .inspire.lock has no inspire_version. $fix"
  [[ $v =~ $SEMVER_RE ]] || refuse "the visor needs INSPIRE $LOCK_FLOOR or later, and .inspire.lock records '$v'. $fix"
  [ "$(ver_cmp "$v" "$LOCK_FLOOR")" != -1 ] \
    || refuse "the visor needs INSPIRE $LOCK_FLOOR or later, and this project is on $v. $fix"
}

read_settings() {
  local f
  VISOR="$ROOT/.inspire/visor"
  KB="$ROOT/inspire_kb"
  Q="$VISOR/.quartz"
  [ -d "$KB" ] || refuse "no inspire_kb/ under $ROOT"
  for f in visor.yaml quartz.config.yaml; do
    [ -f "$VISOR/$f" ] || refuse "no .inspire/visor/$f: run /inspire:update to install the visor's configuration"
  done
  yq -e '.' "$VISOR/visor.yaml" >/dev/null 2>&1 || refuse ".inspire/visor/visor.yaml does not parse"
  QUARTZ="$(yq -r '.quartz // ""' "$VISOR/visor.yaml")"
  NODE_IMAGE="$(yq -r '.node_image // ""' "$VISOR/visor.yaml")"
  [ -n "$PORT" ] || PORT="$(yq -r '.port // ""' "$VISOR/visor.yaml")"
  [[ $QUARTZ =~ $SEMVER_RE ]] || refuse "quartz in .inspire/visor/visor.yaml is '$QUARTZ', not a version X.Y.Z"
  case "$PORT" in ''|*[!0-9]*) refuse "the port '$PORT' is not a number" ;; esac
  # Leading zeros go first: bash reads 010 as octal, and a long number wraps.
  PORT="${PORT#"${PORT%%[!0]*}"}"
  case "$PORT" in ''|??????*) refuse "the port ${PORT:-0} is outside 1-65534" ;; esac
  [ "$PORT" -ge 1 ] && [ "$PORT" -le 65534 ] || refuse "the port $PORT is outside 1-65534"
  # Quartz's live reload needs a second port; deriving it lets two visors run side by side.
  WS_PORT=$((PORT + 1))
}

# The host's Node needs npm too, because the install runs npm ci on it.
pick_runtime() {
  local v="" major=0 found
  if command -v node >/dev/null 2>&1; then
    v="$(node --version 2>/dev/null)"; major="${v#v}"; major="${major%%.*}"
    case "$major" in ''|*[!0-9]*) major=0 ;; esac
  fi
  found="${v:-none}"
  if [ "$major" -ge "$NODE_MIN" ]; then
    if command -v npm >/dev/null 2>&1; then
      RUNTIME="host"; RT=()
      log "visor.sh: runtime: node $v on the host"; return
    fi
    found="$v without npm"
  fi
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    refuse "no runtime: the visor needs node $NODE_MIN or later and npm on PATH (found $found) or a running docker (found none)"
  fi
  [ -n "$NODE_IMAGE" ] || refuse "node_image in .inspire/visor/visor.yaml is empty, and the host has no node $NODE_MIN or later with npm"
  case "$ROOT" in
    *:*) refuse "the project path $ROOT holds a ':', which docker cannot mount: move the project, or put node $NODE_MIN or later and npm on PATH" ;;
  esac
  RUNTIME="docker:$NODE_IMAGE"
  # The project is mounted at its own path so the absolute links Quartz writes under
  # .quartz/ resolve on the host and in the container; the KB is mounted read-only.
  RT=(docker run --rm --init --user "$(id -u):$(id -g)" -e HOME=/tmp
      -v "$ROOT:$ROOT" -v "$KB:$KB:ro" -w "$Q")
  log "visor.sh: runtime: docker, image $NODE_IMAGE (host node: $found)"
}

# One checkout serves one run: a second run rewrites the staged configuration that a
# running serve watches, and rebuilds into the directory it serves.
check_serving() {
  local pid
  pid="$(cat "$Q/.serving" 2>/dev/null)"
  case "$pid" in ''|*[!0-9]*) return 0 ;; esac
  ps -ww -p "$pid" -o command= 2>/dev/null | grep -q 'bootstrap-cli\.mjs build' \
    && refuse "a visor of this project is serving (pid $pid): stop it first"
  return 0
}

# Quartz prints its start line before the bind fails, so a taken port is refused here.
check_ports() {
  local h
  for h in 127.0.0.1 ::1; do
    (exec 3<>"/dev/tcp/$h/$PORT") 2>/dev/null \
      && refuse "the port $PORT is in use on localhost: pass --port N for a free N (the visor uses N and N+1)"
    (exec 3<>"/dev/tcp/$h/$WS_PORT") 2>/dev/null \
      && refuse "the live-reload port $WS_PORT (--port + 1) is in use on localhost: pass --port N for a free N (the visor uses N and N+1)"
  done
  return 0
}

# A container whose docker client was killed keeps its name and both ports.
check_container() {
  [ -z "$(docker ps -aq --filter "name=^/?inspire-visor-$PORT\$" 2>/dev/null)" ] \
    || refuse "a visor container from an earlier run still holds port $PORT: docker stop inspire-visor-$PORT"
}

check_plugin_ranges() {
  local d name range
  for d in "$VISOR/plugins"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    range="$(jq -r '.quartz.quartzVersion // empty' "$d/package.json" 2>/dev/null)"
    [ -n "$range" ] || refuse "the plugin $name declares no quartz.quartzVersion in .inspire/visor/plugins/$name/package.json"
    in_range "$QUARTZ" "$range"
    case $? in
      1) refuse "Quartz $QUARTZ is outside the range the plugin $name works with ($range): set quartz in .inspire/visor/visor.yaml to a version in it" ;;
      2) refuse "the plugin $name declares a Quartz range the visor cannot read: '$range'" ;;
    esac
  done
}

install_failed() {
  log "visor.sh: $1 failed:"
  tail -n 20 "$2" >&2
  exit 3
}

# The stamp is written last, so an install cut short is redone on the next run; it names
# the runtime because node_modules built in a container do not run on the host.
install_quartz() {
  local stamp="$Q/.inspire-visor" want="quartz=$QUARTZ runtime=$RUNTIME"
  if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$want" ]; then
    log "visor.sh: Quartz $QUARTZ is installed in .inspire/visor/.quartz/"; return
  fi
  command -v git >/dev/null 2>&1 || refuse "git is required on PATH to install Quartz"
  log "visor.sh: installing Quartz $QUARTZ into .inspire/visor/.quartz/"
  rm -rf "$Q" 2> "$TMP/rm.log" \
    || install_failed "removing the previous install in .inspire/visor/.quartz/" "$TMP/rm.log"
  git clone -q -c advice.detachedHead=false --depth 1 --branch "v$QUARTZ" "$QUARTZ_REPO" "$Q" \
    > "$TMP/clone.log" 2>&1 || install_failed "git clone of Quartz v$QUARTZ" "$TMP/clone.log"
  (cd "$Q" && rt npm ci --no-audit --no-fund) \
    > "$TMP/npm.log" 2>&1 || install_failed "npm ci in .inspire/visor/.quartz/" "$TMP/npm.log"
  printf '%s\n' "$want" > "$stamp"
}

# rt CMD... — runs CMD in the Quartz checkout on the runtime pick_runtime chose.
rt() {
  if [ "$RUNTIME" = host ]; then "$@"; else "${RT[@]}" "$NODE_IMAGE" "$@"; fi
}

# Quartz writes into a local plugin's directory, so it reads copies inside the checkout.
stage_config() {
  local cfg="$Q/quartz.config.yaml" url
  rm -rf "$Q/plugins"
  if [ -d "$VISOR/plugins" ]; then cp -R "$VISOR/plugins" "$Q/plugins"; else mkdir -p "$Q/plugins"; fi
  cp "$VISOR/quartz.config.yaml" "$cfg"
  url="$(yq -r '.configuration.baseUrl // ""' "$cfg")"
  case "$url" in
    localhost|localhost:*) URL="localhost:$PORT" yq -i '.configuration.baseUrl = strenv(URL)' "$cfg" ;;
  esac
}

# Quartz stops the whole build at a file whose frontmatter it cannot read, so the scan
# runs the checkout's own parser on the chosen runtime, and every file it lists joins the
# staged ignorePatterns with its glob characters escaped.
scan_frontmatter() {
  local cfg="$Q/quartz.config.yaml" out="$TMP/scan.jsonl"
  rt node --input-type=module -e "$(cat "$HERE/visor-scan.mjs")" "$Q" "$KB" \
    > "$out" 2> "$TMP/scan.log" || { log "visor.sh: the frontmatter scan failed:"; tail -n 20 "$TMP/scan.log" >&2; exit 2; }
  SKIPPED="$(jq -s length "$out")" || { log "visor.sh: the frontmatter scan printed something other than JSON"; exit 2; }
  [ "$SKIPPED" -gt 0 ] || return 0
  log "visor.sh: left out of the site, their frontmatter does not parse:"
  jq -r '"  inspire_kb/\(.path): \(.error)"' "$out" >&2
  P="$(jq -sc '[.[].path | gsub("(?<c>[\\[\\]*?{}()!\\\\])"; "\\\(.c)")]' "$out")" \
    yq -i '.configuration.ignorePatterns += env(P)' "$cfg"
}

main() {
  parse_args "$@"
  check_lock
  read_settings
  check_serving
  pick_runtime
  check_plugin_ranges
  if [ "$CHECK" -eq 0 ]; then
    [ "$RUNTIME" = host ] || check_container
    check_ports
  fi
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  install_quartz
  stage_config
  scan_frontmatter
  cd "$Q" || refuse "cannot enter $Q"
  # The copied configuration may list plugins the install has not seen yet.
  rt node quartz/bootstrap-cli.mjs plugin install --from-config \
    > "$TMP/plugins.log" 2>&1 || install_failed "Quartz's plugin install" "$TMP/plugins.log"
  local build
  build=(node quartz/bootstrap-cli.mjs build -d "$KB" -o "$Q/public")
  if [ "$CHECK" -eq 1 ]; then
    rt "${build[@]}" >&2 || { log "visor.sh: the Quartz build failed"; exit 2; }
    log "visor.sh: the site builds ($SKIPPED file(s) left out)"
    exit 0
  fi
  rm -rf "$TMP"; trap - EXIT
  # The first install can take minutes, in which a port can be taken.
  check_ports
  printf '%s\n' "$$" > "$Q/.serving"
  log "visor.sh: serving inspire_kb/ on http://localhost:$PORT"
  if [ "$RUNTIME" = host ]; then
    exec node --import "data:text/javascript;base64,$(base64 < "$HERE/visor-loopback.mjs" | tr -d '\n')" \
      "${build[@]:1}" --serve --port "$PORT" --wsPort "$WS_PORT"
  fi
  log "visor.sh: stop: docker stop inspire-visor-$PORT"
  exec "${RT[@]}" --name "inspire-visor-$PORT" -p "127.0.0.1:$PORT:$PORT" -p "127.0.0.1:$WS_PORT:$WS_PORT" \
    "$NODE_IMAGE" "${build[@]}" --serve --port "$PORT" --wsPort "$WS_PORT"
}

main "$@"
