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
# base/bin/test/ never materializes, and lib/ must not have changed that.
check "BIN-LIB: bin/test/ is still excluded" "[ ! -d '$proj/.inspire/bin/test' ]"

rm -rf "$(dirname "$proj")"
summary
