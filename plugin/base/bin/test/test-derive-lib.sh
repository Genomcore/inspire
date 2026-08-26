#!/usr/bin/env bash
# plugin/base/bin/test/test-derive-lib.sh — the assertions about `derive` that a
# fixture directory cannot make.
#
# `run-tests.sh` runs one fixture at a time and compares one run's stdout with
# one golden file, which covers every per-unit claim the goldens state. Three
# kinds of assertion do not fit that shape and live here instead, wired in by
# hand exactly as `test-trust.sh` and `test-harvest.sh` are:
#
#   ACROSS TWO FIXTURES — that the whitespace/ordinal twins produce a
#   byte-identical claim list, and that changing one dispatch outcome moves
#   exactly one fingerprint. Both are claims about a RELATIONSHIP between two
#   derivations, which no single golden can hold.
#
#   ACROSS A DOCUMENT AND THE CODE — that the universal semantic vocabulary in
#   `lib/derive-types.sh` still equals the table in `type-mapping.md`. The doc
#   stays the authority a human reads; this is what keeps the two from drifting,
#   and it is the reason the vocabulary may ship as data at all (a deployed bin
#   script may not reach into `.claude/skills/` at runtime).
#
#   INSIDE THE LIBRARY — `derive_class_of`'s mapping, including the `DR-U1`
#   catch-all, which no rule emits a message for and therefore no fixture can
#   reach.
#
# Usage: bash plugin/base/bin/test/test-derive-lib.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
BIN="$HERE/.."
FX="$HERE/fixtures/emanate-derive"
SKILLS="$BIN/../skills"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
ne(){ if [ "$2" != "$3" ]; then ok "$1"; else bad "$1 (both are '$2')"; fi; }

# derive_in <fixture> <arg>… — one derivation, run the way the harness runs it.
derive_in() {
  local fx="$1"; shift
  ( cd "$FX/$fx" && SDD_SPEC_ROOT=spec/sdd SDD_KB_ROOT=spec/kb \
      bash "$BIN/emanate-derive.sh" "$@" 2>/dev/null )
}

# ─────────────────────────────────────────────────────────────────────────────
# The universal semantic vocabulary equals the table it documents
# ─────────────────────────────────────────────────────────────────────────────

DOC="$SKILLS/inspire-domain/references/type-mapping.md"
if [ ! -f "$DOC" ]; then
  bad "type-mapping.md is where derive-types.sh says it is"
else
  # The `Semantic` column of § The vocabulary, in document order: the rows
  # between that heading and the next one, first cell, backticks off.
  doc_types="$(awk '
      /^## The vocabulary/ { inside = 1; next }
      /^## / { inside = 0 }
      inside && /^\|/ {
        n = split($0, c, "|")
        if (n < 2) next
        t = c[2]
        gsub(/^[ \t]+|[ \t]+$/, "", t); gsub(/`/, "", t)
        if (t == "" || t == "Semantic" || t ~ /^-+$/) next
        printf "%s%s", (first++ ? " " : ""), t
      }
      END { print "" }
    ' "$DOC")"
  lib_types="$(awk -F= '/^DERIVE_UNIVERSAL_TYPES=/ { gsub(/"/, "", $2); print $2; exit }' \
                 "$BIN/lib/derive-types.sh")"
  eq "universal vocabulary equals type-mapping.md, row for row" "$lib_types" "$doc_types"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Fingerprints cover content, never position
# ─────────────────────────────────────────────────────────────────────────────

twin_a="$(derive_in fingerprint-twin-a action auth.user.create | jq -Sc '.claims')"
twin_b="$(derive_in fingerprint-twin-b action auth.user.create | jq -Sc '.claims')"
eq "the whitespace/ordinal twins produce a byte-identical claim list" "$twin_a" "$twin_b"
ne "and the twins are not both empty" "$twin_a" "[]"

base_screen="$(derive_in clean-screen screen users.list)"
moved_screen="$(derive_in dispatch-outcome-changed screen users.list)"
eq "changing an outcome leaves the claim IDS alone" \
  "$(printf '%s' "$base_screen" | jq -Sc '[.claims[].id]')" \
  "$(printf '%s' "$moved_screen" | jq -Sc '[.claims[].id]')"
changed="$(jq -n --argjson a "$base_screen" --argjson b "$moved_screen" '
    [ $a.claims[] as $x | $b.claims[] | select(.id == $x.id and .fingerprint != $x.fingerprint) | .id ]
  ' | jq -r 'join(",")')"
eq "changing one dispatch outcome moves exactly that dispatch's fingerprint" \
  "$changed" "users.list/dispatch/create"

# ─────────────────────────────────────────────────────────────────────────────
# `--file` names the same unit as `<id>`
# ─────────────────────────────────────────────────────────────────────────────

by_id="$(derive_in clean-entity entity auth.user | jq -S .)"
by_file="$(derive_in clean-entity entity --file spec/sdd/auth/user/auth.user.md | jq -S .)"
eq "--file <path> derives what <id> derives" "$by_id" "$by_file"
ne "and the derivation is not empty" "$by_id" ""

# ─────────────────────────────────────────────────────────────────────────────
# W-1 fires on the fixture whose point is that derive ignores it
# ─────────────────────────────────────────────────────────────────────────────

w1="$( cd "$FX/w1-never-refuses" && SDD_SPEC_ROOT=spec/sdd SDD_KB_ROOT=spec/kb \
       bash "$BIN/constraints-mechanics.sh" 2>&1 >/dev/null | grep -c 'W-1' )"
ne "the W-1 fixture really does provoke a W-1 finding" "$w1" "0"

# ─────────────────────────────────────────────────────────────────────────────
# derive_class_of, including the class no rule can produce a message for
# ─────────────────────────────────────────────────────────────────────────────

DERIVE_TMP="$(mktemp -d -t inspire-derive-lib.XXXXXX)" || exit 1
trap 'rm -rf "$DERIVE_TMP"' EXIT
source "$BIN/_lib.sh"
source "$BIN/_keyed-heads.sh"
source "$BIN/lib/derive-json.sh"
source "$BIN/lib/derive-refusals.sh"

eq "an OS-prefixed message files under its own class" \
  "$(derive_class_of keys-present 'OS-A5: ## Preconditions entry carries no key')" "OS-A5"
eq "a screen-coherence message files under its DR-S id" \
  "$(derive_class_of screen-coherence 'duplicate binding key: ...')" "DR-S7"
eq "a domain section message files under DR-D1" \
  "$(derive_class_of sections-present 'entity document missing required section(s): ## Rationale')" "DR-D1"
eq "an unrecognised message still refuses, under the catch-all" \
  "$(derive_class_of screen-coherence 'some shape nobody has numbered yet')" "DR-U1"
derive_class_of constraints-mechanics 'W-1: `email` still states "unique" in prose'
eq "W-1 is not a class at all — it never refuses" "$?" "1"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
