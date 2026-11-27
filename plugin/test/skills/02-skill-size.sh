#!/usr/bin/env bash
# plugin/scripts/skill-size.sh reports a skill too big for an agent to load well.
# Synthetic skills prove each limit can fire and that characters, not bytes, are
# counted; the shipped skills must hold the hard limits (the size warnings are a
# report for /skill-split, not a gate).
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
LINT="$HERE/../scripts/skill-size.sh"
. "$HERE/lib/assert.sh"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
rep() { awk -v s="$1" -v n="$2" 'BEGIN { for (i = 0; i < n; i++) printf "%s", s }'; }
skill() { mkdir -p "$T/$1"; { printf -- '---\nname: %s\ndescription: %s\n' "$1" "$2"; [ -z "${3:-}" ] || printf 'when_to_use: %s\n' "$3"; printf -- '---\n'; cat; } > "$T/$1/SKILL.md"; }
run() { out="$(bash "$LINT" "$T/$1")"; code=$?; }

echo 'Small.' | skill small 'Does x. Use when y.'
run small; eq "a small skill reports nothing" "$out" ""; eq "a small skill exits 0" "$code" 0

seq 500 | skill long 'Long.'
run long; has "500 lines warn" "$out" "WARN $T/long/SKILL.md: 504 lines"; eq "a warning alone exits 0" "$code" 0

rep 'word ' 4001 | skill heavy 'Heavy.'
run heavy; has "a body over 5000 tokens warns" "$out" "body ~5001 tokens"

echo x | skill accents "$(rep é 1024)"
run accents; eq "1024 two-byte chars are 1024 chars, not 2048" "$out" ""

echo x | skill desc "$(rep a 1025)"
run desc; has "a 1025-char description is an error" "$out" "ERROR $T/desc/SKILL.md: description is 1025 chars"; eq "an error exits 1" "$code" 1

echo x | skill listing "$(rep a 1000)" "$(rep b 537)"
run listing; has "description + when_to_use over 1536 is an error" "$out" "is 1537 chars (max 1536)"

mkdir -p "$T/refs/references"; echo x | skill refs 'Refs.'; rep 'word ' 8001 > "$T/refs/references/big.md"
run refs; has "a reference over 10000 tokens warns" "$out" "WARN $T/refs/references/big.md: ~10001 tokens"

printf '%s\n' '# T' '## A' 'a' '```' '## not a section' '```' '## B' 'b' 'b' > "$T/s.md"
out="$(bash "$LINT" --sections "$T/s.md" | awk '{ print $1, $2, $NF }')"
eq "--sections lists H2s outside fences with their line counts" "$out" "$(printf '1 1 included)\n2 5 A\n7 3 B')"

out="$(bash "$LINT" 2>&1)"; code=$?
hasnt "the shipped skills hold the hard limits" "$out" "ERROR "
eq "the lint over the shipped skills exits 0" "$code" 0
summary
