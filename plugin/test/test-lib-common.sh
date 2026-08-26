#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$HERE/../scripts/lib/common.sh"
. "$HERE/lib/assert.sh"

eq "equal"            "$(version_cmp 0.3.1 0.3.1)"   "0"
eq "patch older"      "$(version_cmp 0.3.0 0.3.1)"   "-1"
eq "patch newer"      "$(version_cmp 0.3.1 0.3.0)"   "1"
eq "minor dominates"  "$(version_cmp 0.2.9 0.3.0)"   "-1"
eq "major dominates"  "$(version_cmp 0.9.9 1.0.0)"   "-1"
eq "double digits"    "$(version_cmp 0.10.0 0.9.0)"  "1"
eq "short vs long"    "$(version_cmp 0.3 0.3.0)"     "0"
eq "missing patch"    "$(version_cmp 0.4 0.3.9)"     "1"

# Regressions found in review: leading zeros previously fell into bash's
# octal parsing of $((...)) (crashing on 8/9 digits, miscomputing otherwise),
# and only the first 3 components were ever compared.
eq "leading zero, same value"   "$(version_cmp 1.09.0 1.9.0)"    "0"
eq "leading zero, real diff"    "$(version_cmp 1.010.0 1.9.0)"   "1"
eq "4th component, older"       "$(version_cmp 1.2.3.4 1.2.3.5)" "-1"
eq "4th component, newer"       "$(version_cmp 1.2.3.5 1.2.3.4)" "1"

tmp="$(mktemp)"; printf 'abc' > "$tmp"
eq "sha256_of" "$(sha256_of "$tmp")" \
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
rm -f "$tmp"

eq "arr_to_json empty" "$(arr_to_json)" "[]"
eq "arr_to_json two"   "$(arr_to_json a b | jq -c .)" '["a","b"]'

# hash_paths. Every case below is a way the batch could silently MISASSOCIATE a
# hash with a path, which in the classifier reads as "you edited this" about a
# file nobody touched.
SHA_ABC="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
SHA_ABCD="88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589"
hp_get(){ p="$2" awk -F'\t' '$2==ENVIRON["p"] {print $1}' "$1"; }

hpd="$(mktemp -d)"; mkdir -p "$hpd/adir"
printf 'abc'  > "$hpd/with space.txt"
printf 'abc'  > "$hpd/quo\"te'and'.txt"
printf 'abcd' > "$hpd/-leading.txt"
printf 'abc'  > "$hpd/back\\slash.txt"
hplist="$(mktemp)"; hptab="$(mktemp)"
printf '%s\0' "with space.txt" "quo\"te'and'.txt" "-leading.txt" \
              "back\\slash.txt" "adir" "gone.txt" > "$hplist"
hperr="$(hash_paths "$hpd" "$hplist" "$hptab" 2>&1 >/dev/null)"

eq "hash_paths: one row per regular file, non-files dropped" \
   "$(wc -l < "$hptab" | tr -d ' ')" "4"
eq "hash_paths: a path with spaces"        "$(hp_get "$hptab" 'with space.txt')"    "$SHA_ABC"
eq "hash_paths: a path with both quotes"   "$(hp_get "$hptab" "quo\"te'and'.txt")"  "$SHA_ABC"
eq "hash_paths: a path starting with a dash" "$(hp_get "$hptab" '-leading.txt')"    "$SHA_ABCD"
# The tools that escape would print this path as `back\\slash.txt` behind a
# leading `\`; the table must carry the literal name and the right hash.
eq "hash_paths: a path containing a backslash" "$(hp_get "$hptab" 'back\slash.txt')" "$SHA_ABC"
eq "hash_paths: a directory is absent from the table" "$(hp_get "$hptab" 'adir')" ""
eq "hash_paths: an absent path is absent from the table" "$(hp_get "$hptab" 'gone.txt')" ""
eq "hash_paths: nothing is written to stderr" "$hperr" ""

hprev="$(mktemp)"; hprtab="$(mktemp)"
printf '%s\0' "back\\slash.txt" "-leading.txt" "quo\"te'and'.txt" "with space.txt" > "$hprev"
hash_paths "$hpd" "$hprev" "$hprtab"
eq "hash_paths: reversed list keeps each path's own hash (dash)" \
   "$(hp_get "$hprtab" '-leading.txt')" "$SHA_ABCD"
eq "hash_paths: reversed list keeps each path's own hash (backslash)" \
   "$(hp_get "$hprtab" 'back\slash.txt')" "$SHA_ABC"
eq "hash_paths: reversed list is in reversed order" \
   "$(head -1 "$hprtab" | cut -f2)" 'back\slash.txt'

# The fallback is forced by a PATH that cannot see sha256sum: /sbin is where
# this machine keeps it.
eq "premise: the fallback run cannot see sha256sum" \
   "$(PATH=/usr/bin:/bin bash -c 'command -v sha256sum >/dev/null 2>&1 && echo yes || echo no')" "no"
hpfb="$(mktemp)"
PATH=/usr/bin:/bin bash -c '. "$1"; hash_paths "$2" "$3" "$4"' \
  _ "$HERE/../scripts/lib/common.sh" "$hpd" "$hplist" "$hpfb" 2>/dev/null
eq "hash_paths: the shasum fallback yields the same table" \
   "$(cat "$hpfb")" "$(cat "$hptab")"

# An empty list spawns nothing at all — proved with a stub on PATH that leaves a
# marker when it runs, and shown non-vacuous by a non-empty list that trips it.
hpe="$(mktemp)"; : > "$hpe"; hpet="$(mktemp)"; hpst="$(mktemp)"
hash_paths "$hpd" "$hpe" "$hpet"; hp_rc=$?
eq "hash_paths: an empty list exits 0" "$hp_rc" "0"
eq "hash_paths: an empty list yields an empty table" "$(wc -c < "$hpet" | tr -d ' ')" "0"
hpsd="$(mktemp -d)"
printf '#!/bin/sh\ntouch "%s/spawned"\n' "$hpsd" > "$hpsd/sha256sum"
chmod 755 "$hpsd/sha256sum"
PATH="$hpsd:$PATH" bash -c '. "$1"; hash_paths "$2" "$3" "$4"' \
  _ "$HERE/../scripts/lib/common.sh" "$hpd" "$hpe" "$hpet" 2>/dev/null
eq "hash_paths: an empty list spawns no hashing process" \
   "$([ -e "$hpsd/spawned" ] && echo yes || echo no)" "no"
PATH="$hpsd:$PATH" bash -c '. "$1"; hash_paths "$2" "$3" "$4"' \
  _ "$HERE/../scripts/lib/common.sh" "$hpd" "$hplist" "$hpst" 2>/dev/null
eq "premise: a non-empty list does spawn it (the marker works)" \
   "$([ -e "$hpsd/spawned" ] && echo yes || echo no)" "yes"

# A file that cannot be READ makes the tool print no line for it. Without the
# count check that would shift every later hash onto the wrong path.
hpu="$(mktemp -d)"
printf 'abc'  > "$hpu/a.txt"
printf 'abcd' > "$hpu/locked.txt"
printf 'abc'  > "$hpu/b.txt"
chmod 000 "$hpu/locked.txt"
hpul="$(mktemp)"; hput="$(mktemp)"
printf '%s\0' a.txt locked.txt b.txt > "$hpul"
hash_paths "$hpu" "$hpul" "$hput" 2>/dev/null   # the tool names the unreadable file, as sha256_of does today
eq "hash_paths: an unreadable file does not shift its neighbours (first)" \
   "$(hp_get "$hput" 'a.txt')" "$SHA_ABC"
eq "hash_paths: an unreadable file does not shift its neighbours (last)" \
   "$(hp_get "$hput" 'b.txt')" "$SHA_ABC"
chmod 644 "$hpu/locked.txt"

rm -rf "$hpd" "$hpu" "$hpsd"
rm -f "$hplist" "$hptab" "$hprev" "$hprtab" "$hpfb" "$hpe" "$hpet" "$hpst" "$hpul" "$hput"

summary
