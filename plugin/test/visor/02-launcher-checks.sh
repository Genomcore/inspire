#!/usr/bin/env bash
# visor.sh refuses before it installs anything: its flags, the INSPIRE 0.17.0 floor of
# .inspire.lock, a missing inspire_kb/ or .inspire/visor/, and a Quartz version outside
# a plugin's quartzVersion range.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$(cd -P "$HERE/.." && pwd -P)"
. "$HERE/lib/assert.sh"
. "$HERE/lib/visor-helpers.sh"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
B="$T/bin"; S="$T/stubs"; mkdir -p "$S"
visor_bin "$B"
stub_node "$S" v22.11.0 "$T/node.log"
stub_npm "$S"
stub_git_fail "$S"
P="$S:$B:/usr/bin:/bin"

# --- flags -----------------------------------------------------------------
run_visor "$P"
eq "no --project-root: exit 1" "$RC" 1
has "no --project-root: the message names the flag" "$OUT" "--project-root is required"
run_visor "$P" --project-root "$T" --serve
eq "an unknown flag: exit 1" "$RC" 1
has "an unknown flag: the message names it" "$OUT" "unknown flag '--serve'"

# --- the INSPIRE 0.17.0 floor ----------------------------------------------
visor_project "$T/p"
rm "$T/p/.inspire.lock"
run_visor "$P" --project-root "$T/p" --check
eq "no .inspire.lock: exit 1" "$RC" 1
has "no .inspire.lock: the message names the floor" "$OUT" "INSPIRE 0.17.0 or later"
has "no .inspire.lock: the message names the missing lock" "$OUT" "has no .inspire.lock"
has "no .inspire.lock: the message names /inspire:migrate" "$OUT" "/inspire:migrate"

printf '{"released":"2026-11-12"}\n' > "$T/p/.inspire.lock"
run_visor "$P" --project-root "$T/p" --check
eq "a lock without inspire_version: exit 1" "$RC" 1
has "a lock without inspire_version: the message names the field" "$OUT" ".inspire.lock has no inspire_version"
has "a lock without inspire_version: the message names /inspire:migrate" "$OUT" "/inspire:migrate"

printf '{"inspire_version":"0.16.2"}\n' > "$T/p/.inspire.lock"
run_visor "$P" --project-root "$T/p" --check
eq "a lock on 0.16.2: exit 1" "$RC" 1
has "a lock on 0.16.2: the message names the project's version" "$OUT" "this project is on 0.16.2"
has "a lock on 0.16.2: the message names the floor" "$OUT" "INSPIRE 0.17.0 or later"
has "a lock on 0.16.2: the message names /inspire:migrate" "$OUT" "/inspire:migrate"

printf '{"inspire_version":"0.9.11"}\n' > "$T/p/.inspire.lock"
run_visor "$P" --project-root "$T/p" --check
has "a lock on 0.9.11 compares by number, not as text" "$OUT" "this project is on 0.9.11"

printf '{"inspire_version":"0.17.0"}\n' > "$T/p/.inspire.lock"
run_visor "$P" --project-root "$T/p" --check
hasnt "a lock on 0.17.0 passes the floor" "$OUT" "INSPIRE 0.17.0 or later"
has "a lock on 0.17.0 goes on to the install" "$OUT" "installing Quartz"

# --- inspire_kb/ and .inspire/visor/ --------------------------------------
visor_project "$T/nokb"
rm -rf "$T/nokb/inspire_kb"
run_visor "$P" --project-root "$T/nokb" --check
eq "no inspire_kb/: exit 1" "$RC" 1
has "no inspire_kb/: the message names it" "$OUT" "no inspire_kb/"

visor_project "$T/novisor"
rm -rf "$T/novisor/.inspire/visor"
run_visor "$P" --project-root "$T/novisor" --check
eq "no .inspire/visor/: exit 1" "$RC" 1
has "no .inspire/visor/: the message points to /inspire:update" "$OUT" "run /inspire:update"

visor_project "$T/badport"
run_visor "$P" --project-root "$T/badport" --check --port 80a
eq "a port that is not a number: exit 1" "$RC" 1
has "a port that is not a number: the message names it" "$OUT" "the port '80a' is not a number"
run_visor "$P" --project-root "$T/badport" --check --port 65535
eq "--port 65535 leaves no port for live reload: exit 1" "$RC" 1
has "--port 65535: the message names the range" "$OUT" "the port 65535 is outside 1-65534"
run_visor "$P" --project-root "$T/badport" --check --port 0
eq "--port 0: exit 1" "$RC" 1
run_visor "$P" --project-root "$T/badport" --check --port 08080
has "a port with a leading zero reads as decimal and goes on to the install" "$OUT" "installing Quartz"

# --- the Quartz version against each plugin's range ------------------------
# set_range PROJECT PLUGIN RANGE — writes quartz.quartzVersion; an empty RANGE deletes it.
set_range() {
  local pkg="$1/.inspire/visor/plugins/$2/package.json"
  R="$3" jq 'if env.R == "" then del(.quartz.quartzVersion) else .quartz.quartzVersion = env.R end' \
    "$pkg" > "$pkg.new" && mv "$pkg.new" "$pkg"
}
set_quartz() { Q="$2" yq -i '.quartz = strenv(Q)' "$1/.inspire/visor/visor.yaml"; }

visor_project "$T/r"
set_range "$T/r" inspire ">=5.1.0 <6.0.0"
set_range "$T/r" inspire-graph ">=5.1.0"
run_visor "$P" --project-root "$T/r" --check
has "5.1.0 inside '>=5.1.0 <6.0.0' and '>=5.1.0' goes on to the install" "$OUT" "installing Quartz 5.1.0"
eq "5.1.0 inside both ranges: the run ends at the stubbed clone (exit 3)" "$RC" 3

set_quartz "$T/r" 6.0.0
run_visor "$P" --project-root "$T/r" --check
eq "6.0.0 against '<6.0.0': exit 1" "$RC" 1
has "6.0.0 against '<6.0.0': the message names the version, the plugin and its range" "$OUT" \
  "Quartz 6.0.0 is outside the range the plugin inspire works with (>=5.1.0 <6.0.0)"
hasnt "6.0.0 against '<6.0.0': nothing is installed" "$OUT" "installing Quartz"

set_quartz "$T/r" 5.0.9
run_visor "$P" --project-root "$T/r" --check
has "5.0.9 against '>=5.1.0': refused, naming both" "$OUT" "Quartz 5.0.9 is outside the range the plugin inspire"

set_quartz "$T/r" 5.10.0
run_visor "$P" --project-root "$T/r" --check
has "5.10.0 is inside '>=5.1.0 <6.0.0': components compare as numbers" "$OUT" "installing Quartz 5.10.0"

set_quartz "$T/r" 5.1
run_visor "$P" --project-root "$T/r" --check
eq "a quartz value that is not X.Y.Z: exit 1" "$RC" 1
has "a quartz value that is not X.Y.Z: the message names it" "$OUT" "quartz in .inspire/visor/visor.yaml is '5.1'"

set_quartz "$T/r" 5.1.0
set_range "$T/r" inspire-graph "^5.1.0"
run_visor "$P" --project-root "$T/r" --check
eq "a range the launcher cannot read ('^5.1.0'): exit 1" "$RC" 1
has "a range the launcher cannot read: the message names the plugin and the range" "$OUT" \
  "the plugin inspire-graph declares a Quartz range the visor cannot read: '^5.1.0'"

set_range "$T/r" inspire-graph ">=5.1.0 || >=6.0.0"
run_visor "$P" --project-root "$T/r" --check
has "an alternation of ranges is refused as unreadable" "$OUT" "cannot read: '>=5.1.0 || >=6.0.0'"

set_range "$T/r" inspire-graph "*"
run_visor "$P" --project-root "$T/r" --check
has "a '*' range is refused as unreadable, not expanded as a glob" "$OUT" "cannot read: '*'"

set_range "$T/r" inspire-graph ""
run_visor "$P" --project-root "$T/r" --check
eq "a plugin without quartzVersion: exit 1" "$RC" 1
has "a plugin without quartzVersion: the message names the plugin" "$OUT" \
  "the plugin inspire-graph declares no quartz.quartzVersion"
summary
