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
