#!/usr/bin/env bash
# visor.sh refuses a serve it cannot start: a port or live-reload port in use, a visor
# container left from an earlier run, a visor of the same project already serving. On the
# host's Node the server listens on 127.0.0.1 only. node and docker are stubs; the ports
# are held by a real listener, and the loopback preload runs on a real node when present.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$(cd -P "$HERE/.." && pwd -P)"
. "$HERE/lib/assert.sh"
. "$HERE/lib/visor-helpers.sh"

T="$(mktemp -d)"
LISTENER=""; SERVER=""
trap '[ -z "$LISTENER" ] || kill "$LISTENER" 2>/dev/null; [ -z "$SERVER" ] || kill "$SERVER" 2>/dev/null; rm -rf "$T"' EXIT
T="$(cd -P "$T" && pwd -P)"
B="$T/bin"; S="$T/stubs"; mkdir -p "$S"
visor_bin "$B"
stub_node "$S" v22.11.0 "$T/node.log"
stub_npm "$S"
P="$S:$B:/usr/bin:/bin"
R="$T/p"; Q="$R/.inspire/visor/.quartz"
visor_project "$R"
visor_installed "$R" host

# --- the host's node listens on 127.0.0.1 only ------------------------------
FP="$(free_port)"
run_visor "$P" --project-root "$R" --port "$FP"
eq "a serve on the host's node: exit 0" "$RC" 0
L="$(grep -- '--serve' "$T/node.log")"
has "the host's serve preloads the loopback module" "$L" "node --import data:text/javascript;base64,"
has "the preload comes before Quartz's entry point" "$L" " quartz/bootstrap-cli.mjs build -d "
URL="$(printf '%s\n' "$L" | sed -n 's/^node --import \(data:[^ ]*\) .*/\1/p')"
if command -v node >/dev/null 2>&1 && [ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -ge 22 ]; then
  # bound ADDR — the address a server lands on under the preload, for listen(ADDR's args).
  bound() { node --import "$URL" -e "const s = require('$1').createServer(); s.listen($2); s.on('listening', () => { console.log(s.address().address); s.close() })" 2>&1; }
  eq "under the preload, listen(port) binds 127.0.0.1" "$(bound net 0)" "127.0.0.1"
  eq "under the preload, listen(port, null, null, cb) binds 127.0.0.1 (the live-reload server's call)" \
    "$(bound http '0, null, null, () => {}')" "127.0.0.1"
  eq "under the preload, listen(port, undefined, cb) binds 127.0.0.1" \
    "$(bound http '0, undefined, () => {}')" "127.0.0.1"
  eq "under the preload, listen({port}) binds 127.0.0.1" "$(bound net '{ port: 0 }')" "127.0.0.1"
  eq "under the preload, a host the caller names is kept" "$(bound net "0, '0.0.0.0'")" "0.0.0.0"
else
  skipped 5 "the loopback preload on a real node (no Node 22 or later)"
fi

# --- a port in use -----------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  # A listener on L whose L-1 is free, so --port L-1 meets only a taken live-reload port.
  python3 -c '
import socket
while True:
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]
    t = socket.socket()
    try:
        t.bind(("127.0.0.1", p - 1)); t.close(); break
    except OSError:
        t.close(); s.close()
s.listen(16); s.settimeout(120); print(p, flush=True)
while True:
    s.accept()[0].close()' > "$T/listener" 2>/dev/null &
  LISTENER=$!
  i=0; while [ ! -s "$T/listener" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
  LP="$(head -n 1 "$T/listener")"
  premise "the listener holds its port" "port_open '$LP'"
  : > "$T/node.log"
  run_visor "$P" --project-root "$R" --port "$LP"
  eq "a port in use: exit 1" "$RC" 1
  has "a port in use: the refusal names the port and --port" "$OUT" "the port $LP is in use on localhost: pass --port N"
  run_visor "$P" --project-root "$R" --port $((LP - 1))
  eq "a live-reload port in use: exit 1" "$RC" 1
  has "a live-reload port in use: the refusal names it" "$OUT" "the live-reload port $LP (--port + 1) is in use"
  eq "a port in use: Quartz never starts" "$(grep -c -- '--serve' "$T/node.log")" "0"
  run_visor "$P" --project-root "$R" --port "$LP" --check
  eq "--check serves nothing, so a port in use does not stop it" "$RC" 0
  kill "$LISTENER" 2>/dev/null; wait "$LISTENER" 2>/dev/null; LISTENER=""
else
  skipped 7 "a port in use (no python3 to hold one)"
fi

# --- a visor container left from an earlier run -----------------------------
IMAGE="$(yq -r .node_image "$R/.inspire/visor/visor.yaml")"
D="$T/docker"; mkdir -p "$D"
stub_node "$D" v20.18.1 "$T/dnode.log"
stub_docker "$D" "$T/docker.log" 4f1c2a9e
: > "$T/docker.log"
visor_installed "$R" "docker:$IMAGE"
FP="$(free_port)"
run_visor "$D:$B:/usr/bin:/bin" --project-root "$R" --port "$FP"
eq "a leftover visor container: exit 1" "$RC" 1
has "a leftover visor container: the refusal gives the command that stops it" "$OUT" \
  "a visor container from an earlier run still holds port $FP: docker stop inspire-visor-$FP"
eq "a leftover visor container: no container starts" "$(grep -c 'docker run' "$T/docker.log")" "0"
stub_docker "$D" "$T/docker.log"
run_visor "$D:$B:/usr/bin:/bin" --project-root "$R" --port "$FP"
has "without a leftover container the serve starts" "$(cat "$T/docker.log")" "--name inspire-visor-$FP"

# --- a visor of the same project already serving ----------------------------
visor_installed "$R" host
printf '#!/bin/sh\nsleep 60\n' > "$T/serving"; chmod +x "$T/serving"
"$T/serving" quartz/bootstrap-cli.mjs build -d x --serve &
SERVER=$!
printf '%s\n' "$SERVER" > "$Q/.serving"
run_visor "$P" --project-root "$R" --check
eq "a visor of this project serving: --check exits 1" "$RC" 1
has "a visor of this project serving: the refusal names its pid" "$OUT" "a visor of this project is serving (pid $SERVER): stop it first"
kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null; SERVER=""
run_visor "$P" --project-root "$R" --check
eq "a serve marker whose process is gone does not stop a run" "$RC" 0
summary
