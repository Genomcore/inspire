#!/usr/bin/env bash
# factory-check.sh warns before a project's emanate.json is moved under `factory`
# when the Factory is older than 0.13.0 or its version cannot be read.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
SCRIPT="$PLUGIN_ROOT/scripts/factory-check.sh"
. "$HERE/lib/assert.sh"

check "factory-check.sh exists and runs" "[ -x '$SCRIPT' ]"

W="$(mktemp -d)"
mkdir -p "$W/with-json/.inspire" "$W/without-json/.inspire"
echo '{}' > "$W/with-json/.inspire/emanate.json"
premise "the project with the old file has it" "[ -f '$W/with-json/.inspire/emanate.json' ]"
premise "the project without it does not" "[ ! -e '$W/without-json/.inspire/emanate.json' ]"

# factory <version> — a Factory checkout carrying that version.
factory() { mkdir -p "$W/f-$1/orchestrator"; printf '{"version":"%s"}\n' "$1" > "$W/f-$1/orchestrator/package.json"; echo "$W/f-$1"; }
run() { out="$(INSPIRE_FACTORY_ROOT="$2" bash "$SCRIPT" --project-root "$1" 2>&1)"; rc=$?; }

run "$W/without-json" "$(factory 0.12.3)"
eq "no emanate.json: exit 0" "$rc" "0"
eq "no emanate.json: silent, even with an old Factory" "$out" ""

run "$W/with-json" "$(factory 0.13.0)"
eq "Factory 0.13.0: exit 0" "$rc" "0"
has "Factory 0.13.0: points at the migration" "$out" "/inspire-config init"

run "$W/with-json" "$(factory 0.20.0)"
eq "Factory 0.20.0 is newer than 0.13.0, not older as a string" "$rc" "0"

run "$W/with-json" "$(factory 0.12.3)"
eq "Factory 0.12.3: exit 1" "$rc" "1"
has "Factory 0.12.3: says not to migrate" "$out" "Do not move its keys"
has "Factory 0.12.3: names the version" "$out" "Factory 0.12.3 is older than 0.13.0"

run "$W/with-json" "$(factory 0.9.9)"
eq "Factory 0.9.9 is older than 0.13.0, not newer as a string" "$rc" "1"

run "$W/with-json" "$W/no-such-checkout"
eq "unreadable version: exit 1" "$rc" "1"
has "unreadable version: says so" "$out" "cannot be read"

out="$(env -u INSPIRE_FACTORY_ROOT bash "$SCRIPT" --project-root "$W/with-json" 2>&1)"; rc=$?
eq "INSPIRE_FACTORY_ROOT unset: exit 1" "$rc" "1"

US="$PLUGIN_ROOT/skills/update/SKILL.md"
check "update skill runs factory-check.sh" "grep -q 'scripts/factory-check.sh' '$US'"

rm -rf "$W"
summary
