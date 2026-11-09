#!/usr/bin/env bash
# factory-check.sh checks the Factory's version against the range this INSPIRE
# version declares in plugin/factory-compat.json, and /inspire:update runs it
# when the skill loads.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
SCRIPT="$PLUGIN_ROOT/scripts/factory-check.sh"
COMPAT="$PLUGIN_ROOT/factory-compat.json"
. "$HERE/lib/assert.sh"

check "factory-check.sh exists" "[ -x '$SCRIPT' ]"
eq "shipped compat file declares min 0.13.0" "$(jq -r .factory.min "$COMPAT")" "0.13.0"
eq "shipped compat file declares no max" "$(jq -r '.factory.max' "$COMPAT")" "null"

W="$(mktemp -d)"
mkdir -p "$W/json/.inspire" "$W/yml/.inspire" "$W/none/.inspire"
echo '{}' > "$W/json/.inspire/emanate.json"
echo 'image: {}' > "$W/yml/.inspire/emanate.yml"
premise "json project has the old file" "[ -f '$W/json/.inspire/emanate.json' ]"
premise "yml project has the new file" "[ -f '$W/yml/.inspire/emanate.yml' ]"
premise "none project uses neither" "[ ! -e '$W/none/.inspire/emanate.json' ] && [ ! -e '$W/none/.inspire/emanate.yml' ]"

factory() { mkdir -p "$W/f-$1/orchestrator"; printf '{"version":"%s"}\n' "$1" > "$W/f-$1/orchestrator/package.json"; echo "$W/f-$1"; }
run() { out="$(INSPIRE_FACTORY_ROOT="$2" bash "$SCRIPT" --project-root "$1" 2>&1)"; rc=$?; }

run "$W/none" "$(factory 0.9.9)"
eq "project without the Factory: exit 0" "$rc" "0"
eq "project without the Factory: silent" "$out" ""

run "$W/yml" "$(factory 0.13.0)"
eq "0.13.0 on a migrated project: exit 0" "$rc" "0"
eq "0.13.0 on a migrated project: silent" "$out" ""

run "$W/json" "$(factory 0.13.0)"
eq "0.13.0 with the old file: exit 0" "$rc" "0"
has "0.13.0 with the old file: points at the migration" "$out" "/inspire-config init"

run "$W/json" "$(factory 0.20.0)"
eq "0.20.0 is newer than 0.13.0, not older as a string" "$rc" "0"

run "$W/yml" "$(factory 0.12.3)"
eq "0.12.3: exit 1" "$rc" "1"
has "0.12.3: names version and minimum" "$out" "Factory 0.12.3 is older than 0.13.0"

run "$W/yml" "$(factory 0.9.9)"
eq "0.9.9 is older than 0.13.0, not newer as a string" "$rc" "1"

run "$W/json" "$W/no-such-checkout"
eq "unreadable version: exit 0, a warning only" "$rc" "0"
has "unreadable version: says so" "$out" "cannot be read"
has "unreadable version: states the range" "$out" "0.13.0 or later"

out="$(env -u INSPIRE_FACTORY_ROOT bash "$SCRIPT" --project-root "$W/json" 2>&1)"; rc=$?
eq "INSPIRE_FACTORY_ROOT unset: exit 0" "$rc" "0"
has "INSPIRE_FACTORY_ROOT unset: warns" "$out" "cannot be read"

echo '{"factory":{"min":"0.13.0","max":"0.14.0"}}' > "$W/capped.json"
run2() { out="$(INSPIRE_FACTORY_ROOT="$1" bash "$SCRIPT" --project-root "$W/yml" --compat "$W/capped.json" 2>&1)"; rc=$?; }
run2 "$(factory 0.14.0)"
eq "max 0.14.0: 0.14.0 is in range" "$rc" "0"
run2 "$(factory 0.15.0)"
eq "max 0.14.0: 0.15.0 is out" "$rc" "1"
has "max 0.14.0: says newer" "$out" "newer than 0.14.0"
run2 "$(factory 0.100.0)"
eq "max 0.14.0: 0.100.0 is out, not smaller as a string" "$rc" "1"

echo '{}' > "$W/empty.json"
out="$(INSPIRE_FACTORY_ROOT="$(factory 0.13.0)" bash "$SCRIPT" --project-root "$W/yml" --compat "$W/empty.json" 2>&1)"; rc=$?
eq "a compat file without min: exit 2" "$rc" "2"

US="$PLUGIN_ROOT/skills/update/SKILL.md"
check "update skill injects the check when it loads" "grep -q '^!\`\"\${CLAUDE_PLUGIN_ROOT}/scripts/factory-check.sh\"\`' '$US'"
check "update skill pre-approves exactly that command" "grep -q '^allowed-tools: Bash(\${CLAUDE_PLUGIN_ROOT}/scripts/factory-check.sh)' '$US'"

rm -rf "$W"
summary
