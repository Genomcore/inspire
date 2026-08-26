#!/usr/bin/env bash
# An unmigrated v0.2 tree must be refused by init.
# Moved from test-materialize.sh:626-657.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

# ---------------------------------------------------------------------------
# An UNMIGRATED v0.2 tree (.inspire_kb/ present, inspire_kb/ absent) must be
# refused by init. The lock guard cannot catch it: the operator may have
# deleted the lock by hand, or never had one. Unguarded, init exits 0
# reporting a clean install while the entire knowledge base sits at
# .inspire_kb/, a path no v0.3 skill reads, with an empty inspire_kb/ seeded
# beside it. `/inspire:init` never migrates a project in place — the remedy
# is `/inspire:update`, which runs the hop chain this fixture would otherwise
# need by hand.
# ---------------------------------------------------------------------------
um="$(mktemp -d)/umproj"; mkdir -p "$um/.inspire_kb/03_features"; ( cd "$um" && git init -q )
printf -- '# Login\n\nThe real, only copy.\n' > "$um/.inspire_kb/03_features/feat-login.md"
umerr="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$um" \
  --source-root source --prototype-root prototype 2>&1 >/dev/null)"
rc_um=$?
check "unmigrated v0.2: init exits 1"                 "[ '$rc_um' = 1 ]"
check "unmigrated v0.2: points at /inspire:update"    "printf '%s' \"\$umerr\" | grep -q '/inspire:update'"
check "unmigrated v0.2: no empty KB seeded beside it" "[ ! -e '$um/inspire_kb' ]"
check "unmigrated v0.2: nothing written at all"       "[ ! -d '$um/.claude/skills' ] && [ ! -f '$um/.inspire.lock' ]"
check "unmigrated v0.2: the old KB is untouched"      "[ -f '$um/.inspire_kb/03_features/feat-login.md' ]"

# Once the layout is actually moved the guard must stand down — otherwise it
# blocks the very migration it points the operator at.
( cd "$um" && mv .inspire_kb inspire_kb )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$um" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
rc_um2=$?
check "migrated v0.2: init now succeeds"              "[ '$rc_um2' = 0 ]"
check "migrated v0.2: the migrated KB survives it"    "[ -f '$um/inspire_kb/03_features/feat-login.md' ] && grep -q 'The real, only copy' '$um/inspire_kb/03_features/feat-login.md'"
check "migrated v0.2: skeleton filled in around it"   "[ -f '$um/inspire_kb/03_features/README.md' ] && [ -f '$um/inspire_kb/99_tracker/README.md' ]"
rm -rf "$(dirname "$um")"

summary
