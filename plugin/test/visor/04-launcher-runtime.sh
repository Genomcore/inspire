#!/usr/bin/env bash
# visor.sh picks its runtime: host node 22 or later, else Docker with visor.yaml's
# node_image, else a refusal naming both. It installs Quartz again when the install's
# stamp names another version or another runtime. node, docker and git are stubs.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$(cd -P "$HERE/.." && pwd -P)"
. "$HERE/lib/assert.sh"
. "$HERE/lib/visor-helpers.sh"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
T="$(cd -P "$T" && pwd -P)"
B="$T/bin"; visor_bin "$B"
IMAGE="$(yq -r .node_image "$PLUGIN_ROOT/base/visor/visor.yaml")"

# stubs NAME — a fresh stub directory $T/NAME and its empty logs.
stubs() { S="$T/$1"; mkdir -p "$S"; : > "$S/node.log"; : > "$S/docker.log"; }

R="$T/p"; KB="$R/inspire_kb"; Q="$R/.inspire/visor/.quartz"
visor_project "$R"

# --- host node 22 or later -------------------------------------------------
stubs new; stub_node "$S" v22.0.0 "$S/node.log"; stub_npm "$S"; stub_docker "$S" "$S/docker.log"
visor_installed "$R" host
run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
eq "node v22.0.0 and docker: exit 0" "$RC" 0
has "node v22.0.0 and docker: the host's node runs Quartz" "$OUT" "runtime: node v22.0.0 on the host"
has "the host's node runs the build" "$(cat "$S/node.log")" "node quartz/bootstrap-cli.mjs build -d $KB"
has "the host's node runs the frontmatter scan" "$(cat "$S/node.log")" "node scan $Q $KB"
eq "docker is not called when the host has node 22" "$(cat "$S/docker.log")" ""

# --- docker when the host's node has no npm ---------------------------------
stubs nonpm; stub_node "$S" v22.11.0 "$S/node.log"; stub_docker "$S" "$S/docker.log"
visor_installed "$R" "docker:$IMAGE"
if [ ! -e /usr/bin/npm ] && [ ! -e /bin/npm ]; then
  run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
  eq "node v22.11.0 without npm, and docker: exit 0" "$RC" 0
  has "node v22.11.0 without npm, and docker: docker runs Quartz" "$OUT" \
    "runtime: docker, image $IMAGE (host node: v22.11.0 without npm)"
  rm "$S/docker"
  run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
  eq "node v22.11.0 without npm, and no docker: exit 1" "$RC" 1
  has "node v22.11.0 without npm, and no docker: the refusal names npm" "$OUT" \
    "needs node 22 or later and npm on PATH (found v22.11.0 without npm)"
else
  skipped 4 "a host node without npm: /usr/bin or /bin holds npm"
fi

# --- docker when the host's node is older ----------------------------------
stubs old; stub_node "$S" v20.18.1 "$S/node.log"; stub_docker "$S" "$S/docker.log"
visor_installed "$R" "docker:$IMAGE"
run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
eq "node v20.18.1 and docker: exit 0" "$RC" 0
has "node v20.18.1 and docker: docker runs Quartz, naming the image and the host's node" "$OUT" \
  "runtime: docker, image $IMAGE (host node: v20.18.1)"
eq "the host's node is only asked its version" "$(cat "$S/node.log")" ""
D="$(grep ' build ' "$S/docker.log")"
has "the build runs in a removed container with an init process" "$D" "docker run --rm --init --user "
has "the project is mounted at its own path" "$D" "-v $R:$R"
has "inspire_kb/ is mounted read-only" "$D" "-v $KB:$KB:ro"
has "the container works in the Quartz checkout" "$D" "-w $Q"
has "the container runs visor.yaml's node_image and builds inspire_kb/" "$D" \
  "$IMAGE node quartz/bootstrap-cli.mjs build -d $KB -o $Q/public"
hasnt "--check publishes no port" "$D" " -p "
has "the frontmatter scan runs in the container, its script passed as an argument" \
  "$(cat "$S/docker.log")" "-w $Q $IMAGE node --input-type=module -e // plugin/scripts/visor-scan.mjs"

: > "$S/docker.log"
FP="$(free_port)"; WP=$((FP + 1))
run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --port "$FP"
D="$(grep -- '--serve' "$S/docker.log")"
has "a serve in docker names the container after the port" "$D" "--name inspire-visor-$FP"
has "a serve in docker publishes the port and the live-reload port on localhost" "$D" \
  "-p 127.0.0.1:$FP:$FP -p 127.0.0.1:$WP:$WP $IMAGE"
has "a serve in docker passes both ports to Quartz" "$D" "--serve --port $FP --wsPort $WP"
has "a serve in docker says how to stop it" "$OUT" "stop: docker stop inspire-visor-$FP"
hasnt "a serve in docker preloads nothing into the container's node" "$D" "--import"

# --- a project path docker cannot mount --------------------------------------
visor_project "$T/a:b"
visor_installed "$T/a:b" "docker:$IMAGE"
: > "$S/docker.log"
run_visor "$S:$B:/usr/bin:/bin" --project-root "$T/a:b" --check
eq "a project path with ':' under docker: exit 1" "$RC" 1
has "a project path with ':' under docker: the refusal names the ':'" "$OUT" "holds a ':', which docker cannot mount"
eq "a project path with ':' under docker: no container runs" "$(cat "$S/docker.log")" ""

# --- no node at all, or no docker ------------------------------------------
if no_host_runtime; then
  stubs nonode; stub_docker "$S" "$S/docker.log"
  run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
  eq "no node and docker: exit 0" "$RC" 0
  has "no node and docker: docker runs Quartz" "$OUT" "runtime: docker, image $IMAGE (host node: none)"

  stubs nodocker; stub_node "$S" v20.18.1 "$S/node.log"
  run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
  eq "node v20 and no docker: exit 1" "$RC" 1
  has "node v20 and no docker: the refusal names node 22, the node found and docker" "$OUT" \
    "no runtime: the visor needs node 22 or later and npm on PATH (found v20.18.1) or a running docker (found none)"

  stubs neither
  run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
  eq "neither node nor docker: exit 1" "$RC" 1
  has "neither node nor docker: the refusal names both" "$OUT" "node 22 or later and npm on PATH (found none) or a running docker"
else
  skipped 6 "runtime absence: /usr/bin or /bin holds node or docker"
fi

stubs nodaemon; stub_node "$S" v18.20.0 "$S/node.log"
printf '#!/bin/sh\n[ "$1" = info ] && exit 1\necho "docker $*" >> "%s"\n' "$S/docker.log" > "$S/docker"
chmod +x "$S/docker"
run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
eq "a docker whose daemon does not answer counts as no docker: exit 1" "$RC" 1
eq "a docker whose daemon does not answer runs nothing" "$(cat "$S/docker.log")" ""

# --- install again on another version or runtime ----------------------------
stubs reinstall; stub_node "$S" v20.18.1 "$S/node.log"; stub_docker "$S" "$S/docker.log"
printf '#!/bin/sh\necho "git $*" >> "%s"\nfor a; do d="$a"; done\nmkdir -p "$d"\n' "$S/git.log" > "$S/git"
chmod +x "$S/git"
visor_installed "$R" host
echo old > "$Q/left-over"
run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
eq "an install stamped for the host, run in docker: exit 0" "$RC" 0
has "an install stamped for the host is redone for docker" "$OUT" "installing Quartz 5.1.0"
has "the install clones Quartz's tag" "$(cat "$S/git.log")" \
  "clone -q -c advice.detachedHead=false --depth 1 --branch v5.1.0 https://github.com/jackyzha0/quartz.git $Q"
check "the old install is removed first" "[ ! -e '$Q/left-over' ]"
has "npm ci runs in the container" "$(cat "$S/docker.log")" "$IMAGE npm ci --no-audit --no-fund"
eq "the new install is stamped with its version and runtime" \
  "$(cat "$Q/.inspire-visor")" "quartz=5.1.0 runtime=docker:$IMAGE"

printf 'quartz=5.0.0 runtime=docker:%s\n' "$IMAGE" > "$Q/.inspire-visor"
: > "$S/git.log"
run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
has "an install of another Quartz version is redone" "$(cat "$S/git.log")" "--branch v5.1.0"

: > "$S/git.log"
run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
eq "a matching install is not redone" "$(cat "$S/git.log")" ""

printf '#!/bin/sh\n[ "$1" = info ] && exit 0\ncase "$*" in *"npm ci"*) echo "npm error network" >&2; exit 1;; esac\n' > "$S/docker"
rm -f "$Q/.inspire-visor"
run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
eq "a failing npm ci: exit 3" "$RC" 3
has "a failing npm ci: its output is relayed" "$OUT" "npm error network"
check "a failing npm ci leaves no stamp, so the next run installs again" "[ ! -e '$Q/.inspire-visor' ]"

# --- an old install the launcher cannot remove ------------------------------
if [ "$(id -u)" -ne 0 ]; then
  mkdir -p "$Q/owned/elsewhere"; chmod a-w "$Q/owned"
  : > "$S/git.log"
  run_visor "$S:$B:/usr/bin:/bin" --project-root "$R" --check
  chmod u+w "$Q/owned"
  eq "an old install that cannot be removed: exit 3" "$RC" 3
  has "an old install that cannot be removed: the message names .inspire/visor/.quartz/" "$OUT" \
    "removing the previous install in .inspire/visor/.quartz/ failed:"
  eq "an old install that cannot be removed: no clone runs" "$(cat "$S/git.log")" ""
else
  skipped 3 "an old install that cannot be removed: root removes it anyway"
fi
summary
