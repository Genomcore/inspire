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
version_cmp() {
  local a="$1" b="$2" i ai bi
  local -a A B
  IFS=. read -r -a A <<< "$a"
  IFS=. read -r -a B <<< "$b"
  for i in 0 1 2; do
    ai="${A[$i]:-0}"; bi="${B[$i]:-0}"
    ai="${ai%%[^0-9]*}"; bi="${bi%%[^0-9]*}"
    [ -n "$ai" ] || ai=0
    [ -n "$bi" ] || bi=0
    if [ "$((ai))" -lt "$((bi))" ]; then printf '%s\n' -1; return 0; fi
    if [ "$((ai))" -gt "$((bi))" ]; then printf '%s\n' 1;  return 0; fi
  done
  printf '%s\n' 0
}
