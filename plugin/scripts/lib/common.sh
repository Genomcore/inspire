#!/usr/bin/env bash
# Shared helpers. Sourced, never executed. bash 3.2 compatible.

log() { printf '%s\n' "$*" >&2; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# hash_paths <root> <list-file> <out-file>
#
# The batched form of sha256_of: ONE hashing process for a whole set of files
# instead of two spawns (sha256sum + awk) per file. <list-file> holds
# NUL-separated paths relative to <root>; <out-file> receives one
# `<hash><TAB><path>` line per path that is a regular file, in list order.
# A path that is not a regular file (a directory, a dangling link, an absent
# file) is simply ABSENT from the table — the `[ -f ]` guard every caller used to
# carry, moved here once. An empty list spawns nothing and yields an empty table,
# rc 0.
#
# THE SCOPE RULE THAT KEEPS BEHAVIOUR IDENTICAL BY CONSTRUCTION: a batch is
# computed at the start of the function that consumes it and never outlives that
# function. Hops (`mv`) and _apply_write run BETWEEN phases, so no hash ever
# survives a mutation; the same files are hashed at the same moments as before,
# in one process instead of two per file.
#
# ASSOCIATION IS BY LIST ORDER, NEVER BY THE PRINTED PATH. The tools disagree on
# how they print a path, and neither form is round-trippable:
#   · /sbin/sha256sum (Darwin 1.0) prints the path RAW — a backslash or a newline
#     in it comes out verbatim, so a newline splits the line in two.
#   · shasum -a 256 (and GNU sha256sum) ESCAPE: the line is prefixed with `\` and
#     the path's `\` becomes `\\`, its newline `\n`.
# So only the hash column is parsed — with any leading `\` stripped — and the
# path comes from our own ordered list. Consumers join the table with awk: bash
# 3.2 has no associative arrays, so a hash table here is a file.
#
# THE ORDER ASSUMPTION IS CHECKED, NOT TRUSTED. A listed file that cannot be READ
# (permissions, or one that vanished after the `[ -f ]` test) makes the tool print
# an error and no line, which would shift every later hash onto the wrong path —
# silent, and catastrophic in a classifier. So the line count is compared with the
# input count, and on any mismatch the whole batch falls back to per-file hashing,
# which cannot misalign. Slow, correct, and rare.
#
# A PATH CONTAINING A NEWLINE IS UNREACHABLE HERE, and the count check is NOT what
# would save it — say so rather than imply a guard that does not hold. Under
# `sha256sum` the raw name splits the line in two and the count check does trip;
# under the `shasum` fallback the escaped `\n` keeps the hash count equal while
# `names` gains a line, so `paste` would misalign silently. Neither case is
# reachable: a manifest is TSV and a base path comes from the plugin's own tree,
# while a project file with a newline is already split into two bogus lines by the
# `while read` in every consumer before it can reach this function — identically
# on both sides of this change.
hash_paths() {
  local root="$1" list="$2" out="$3"
  local args names hashes p n_in n_out

  : > "$out" || return 1
  args="$(mktemp)"  || return 1
  names="$(mktemp)" || { rm -f "$args"; return 1; }

  n_in=0
  # `|| [ -n "$p" ]` so a list with no trailing NUL still yields its last item.
  while IFS= read -r -d '' p || [ -n "$p" ]; do
    [ -n "$p" ] || continue
    [ -f "$root/$p" ] || continue
    printf '%s\0' "$root/$p" >> "$args"
    printf '%s\n' "$p"       >> "$names"
    n_in=$((n_in + 1))
  done < "$list"

  if [ "$n_in" -eq 0 ]; then
    rm -f "$args" "$names"
    return 0
  fi

  hashes="$(mktemp)" || { rm -f "$args" "$names"; return 1; }
  # xargs -0 splits over the argument-length limit by itself and runs the pieces
  # in order, so list order survives a split batch. `--` because a caller may
  # pass a relative root, which would leave a leading `-` on the first argument.
  if command -v sha256sum >/dev/null 2>&1; then
    xargs -0 sha256sum -- < "$args" 2>/dev/null \
      | awk '{ h=$1; sub(/^\\/, "", h); print h }' > "$hashes"
  else
    xargs -0 shasum -a 256 -- < "$args" 2>/dev/null \
      | awk '{ h=$1; sub(/^\\/, "", h); print h }' > "$hashes"
  fi
  n_out="$(wc -l < "$hashes" | tr -d ' ')"

  if [ "$n_out" = "$n_in" ]; then
    paste -d'\t' "$hashes" "$names" > "$out"
  else
    while IFS= read -r p; do
      printf '%s\t%s\n' "$(sha256_of "$root/$p")" "$p"
    done < "$names" > "$out"
  fi

  rm -f "$args" "$names" "$hashes"
  return 0
}

arr_to_json() {
  if [ "$#" -eq 0 ]; then printf '[]\n'; return 0; fi
  printf '%s\n' "$@" | jq -R -s 'split("\n") | map(select(length > 0))'
}

# version_cmp A B → -1 if A<B, 0 if equal, 1 if A>B.
# Pure bash: `sort -V` is not dependable on BSD sort, and this gates
# destructive work.
#
# Handles: any number of dot-separated components (not just major.minor.patch;
# a 4th+ component is compared, not dropped); a version with fewer components
# than the other treats the missing ones as 0 (so "0.3" == "0.3.0"); every
# component is always read in base 10, even when it has a leading zero (so
# "1.09" and "1.010" don't hit bash's octal parsing in `$((...))`, which would
# otherwise throw on an 8/9 digit or silently miscompute).
# Does NOT handle: prerelease or build-metadata ordering (e.g. "-rc1", "+build")
# — any non-digit suffix on a component is truncated by the `%%[^0-9]*` strip
# below, not compared. Out of scope: INSPIRE has never shipped a prerelease.
version_cmp() {
  local a="$1" b="$2" i n ai bi
  local -a A B
  IFS=. read -r -a A <<< "$a"
  IFS=. read -r -a B <<< "$b"
  n="${#A[@]}"
  [ "${#B[@]}" -gt "$n" ] && n="${#B[@]}"
  i=0
  while [ "$i" -lt "$n" ]; do
    ai="${A[$i]:-0}"; bi="${B[$i]:-0}"
    ai="${ai%%[^0-9]*}"; bi="${bi%%[^0-9]*}"
    [ -n "$ai" ] || ai=0
    [ -n "$bi" ] || bi=0
    if [ "$((10#$ai))" -lt "$((10#$bi))" ]; then printf '%s\n' -1; return 0; fi
    if [ "$((10#$ai))" -gt "$((10#$bi))" ]; then printf '%s\n' 1;  return 0; fi
    i=$((i + 1))
  done
  printf '%s\n' 0
}
