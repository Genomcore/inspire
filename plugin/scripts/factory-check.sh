#!/usr/bin/env bash
# Is the operator's INSPIRE Factory inside the range this INSPIRE version supports?
#
#   factory-check.sh [--project-root DIR] [--compat FILE]
#
# The range is plugin/factory-compat.json: {"factory": {"min": "x.y.z", "max": null}},
# max null meaning no known upper bound. The Factory's version is read from its
# checkout, INSPIRE_FACTORY_ROOT. Speaks only for a project that uses the Factory
# (.inspire/emanate.yml or .inspire/emanate.json).
#   exit 0  nothing to say, in range, or the version cannot be read (a warning only)
#   exit 1  the Factory is outside the range
#   exit 2  usage, or no readable compat file
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
COMPAT="$(cd -P "$(dirname "$0")/.." && pwd -P)/factory-compat.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) ROOT="$2"; shift 2 ;;
    --compat) COMPAT="$2"; shift 2 ;;
    *) printf 'factory-check.sh: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -e "$ROOT/.inspire/emanate.yml" ] || [ -e "$ROOT/.inspire/emanate.json" ] || exit 0

min="$(jq -er '.factory.min' "$COMPAT" 2>/dev/null)" || { printf 'factory-check.sh: no factory.min in %s\n' "$COMPAT" >&2; exit 2; }
max="$(jq -r '.factory.max // empty' "$COMPAT" 2>/dev/null)"
range="$min or later"; [ -n "$max" ] && range="$min to $max"

version=""
if [ -n "${INSPIRE_FACTORY_ROOT:-}" ]; then
  version="$(jq -r '.version // empty' "$INSPIRE_FACTORY_ROOT/orchestrator/package.json" 2>/dev/null)"
fi

# ponytail: dotted numeric versions only; a pre-release tag would need a real semver compare
at_least() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]; }

if [ -z "$version" ]; then
  printf '%s\n' "The Factory's version cannot be read (set INSPIRE_FACTORY_ROOT to its checkout). This INSPIRE supports Factory $range." \
    "Do not move .inspire/emanate.json under \`factory\` until you know the Factory is in that range."
  exit 0
fi
if ! at_least "$version" "$min"; then
  printf '%s\n' "Factory $version is older than $min, the oldest this INSPIRE supports (it supports Factory $range)." \
    "Update the Factory first. Do not move .inspire/emanate.json under \`factory\` before that."
  exit 1
fi
if [ -n "$max" ] && ! at_least "$max" "$version"; then
  printf '%s\n' "Factory $version is newer than $max, the newest this INSPIRE is known to work with (it supports Factory $range)."
  exit 1
fi
[ -e "$ROOT/.inspire/emanate.json" ] && printf '%s\n' "Factory $version is in range. .inspire/emanate.json found: run /inspire-config init to move its keys under \`factory\`."
exit 0
