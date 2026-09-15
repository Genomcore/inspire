#!/usr/bin/env bash
# `base/bin/lib/` is a payload class only by convention: nothing in
# materialize.sh names it, and it lands because apply_base resolves every path
# under base/<name>/ generically and chmod_executables walks base/bin/
# recursively. Both are inferences about someone else's code, so they are
# asserted rather than assumed — a subdirectory that silently stopped
# materializing would leave `emanate-derive.sh` sourcing files that are not
# there, in every project, with nothing else going red.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"

# The SOURCE side first: "the destination exists" passes whether or not the copy
# ran, and a `.inspire/bin/lib/` left by an earlier run would prove nothing.
premise "base/bin/lib/ ships units in the plugin" \
  "[ -n \"\$(ls '$PLUGIN_ROOT'/base/bin/lib/*.sh 2>/dev/null)\" ]"
premise "one of them is the entry's own JSON unit" \
  "[ -f '$PLUGIN_ROOT/base/bin/lib/derive-json.sh' ]"

proj="$(mktemp -d)/binlib"; mkdir -p "$proj"; ( cd "$proj" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype >/dev/null 2>&1

check "BIN-LIB: .inspire/bin/lib/ materializes" "[ -d '$proj/.inspire/bin/lib' ]"

# Every shipped unit lands, by name — a partial copy is the failure this guards.
missing=""
for src in "$PLUGIN_ROOT"/base/bin/lib/*.sh; do
  base="$(basename "$src")"
  [ -f "$proj/.inspire/bin/lib/$base" ] || missing="${missing:+$missing,}$base"
done
eq "BIN-LIB: every shipped lib unit landed" "$missing" ""

# 755, from chmod_executables' recursive walk of base/bin/ (bin/test/ excluded).
# The units ship 644 in the plugin precisely so this is not vacuous: `cp`
# preserves a mode, so an executable source would let the assertion pass whether
# or not the chmod ran.
premise "the shipped units are NOT already executable" \
  "[ ! -x '$PLUGIN_ROOT/base/bin/lib/derive-json.sh' ]"
modes="$(ls -l "$proj"/.inspire/bin/lib/*.sh | awk '{ print substr($1, 2, 9) }' | sort -u)"
eq "BIN-LIB: the units are executable (rwxr-xr-x)" "$modes" "rwxr-xr-x"

check "BIN-LIB: the entry that sources them landed too" \
  "[ -x '$proj/.inspire/bin/emanate-derive.sh' ]"

# The orchestrator ships the only NON-.sh payload under bin/, and the only one
# two levels deep (lib/orchestrator/runners/). Every assertion above is globbed
# to `*.sh`, so none of it sees a single module: a recursion that stopped one
# level short, or an exclusion that grew a `.py` case, would leave
# `.inspire/bin/emanate-orchestrator.py` dying on `ModuleNotFoundError:
# orchestrator` in every project with the estate still green.
premise "base/bin/lib/orchestrator/ ships modules in the plugin" \
  "[ -f '$PLUGIN_ROOT/base/bin/lib/orchestrator/orchestrator.py' ]"
premise "one of them sits a second level down" \
  "[ -f '$PLUGIN_ROOT/base/bin/lib/orchestrator/runners/fake.py' ]"

missing=""
while IFS= read -r src; do
  rel="${src#"$PLUGIN_ROOT"/base/bin/}"
  [ -f "$proj/.inspire/bin/$rel" ] || missing="${missing:+$missing,}$rel"
done < <(find "$PLUGIN_ROOT/base/bin/lib/orchestrator" -type f -name '*.py')
eq "BIN-LIB: every orchestrator module landed" "$missing" ""

# The exact inverse of the units above, and unasserted in both directions until
# now: chmod_executables filters on `-name '*.sh'`, so a module must arrive 644.
modes="$(find "$proj/.inspire/bin/lib/orchestrator" -type f -exec ls -l {} + \
  | awk '{ print substr($1, 2, 9) }' | sort -u)"
eq "BIN-LIB: the modules are NOT executable" "$modes" "rw-r--r--"
check "BIN-LIB: the orchestrator entry landed executable" \
  "[ -x '$proj/.inspire/bin/emanate-orchestrator.py' ]"

# Run from / so a cwd-relative resolution of the package cannot pass by accident.
( cd / && python3 "$proj/.inspire/bin/emanate-orchestrator.py" --help ) \
  >/dev/null 2>&1
eq "BIN-LIB: the deployed entry imports its package" "$?" "0"

# base/bin/test/ never materializes, and lib/ must not have changed that.
check "BIN-LIB: bin/test/ is still excluded" "[ ! -d '$proj/.inspire/bin/test' ]"

rm -rf "$(dirname "$proj")"
summary
