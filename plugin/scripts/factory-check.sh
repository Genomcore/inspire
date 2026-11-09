#!/usr/bin/env bash
# Is the operator's INSPIRE Factory new enough to read `factory:` in emanate.yml?
#
#   factory-check.sh [--project-root DIR]
#
# Speaks only when the project still has .inspire/emanate.json: that is the file
# whose move under `factory` breaks a run on a Factory older than MIN. The
# Factory's version is read from its checkout, INSPIRE_FACTORY_ROOT.
#   exit 0  nothing to say, or the Factory is new enough to migrate to
#   exit 1  the Factory is older than MIN, or its version cannot be read
set -uo pipefail
MIN="0.13.0"
ROOT="."
while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) ROOT="$2"; shift 2 ;;
    *) printf 'factory-check.sh: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -e "$ROOT/.inspire/emanate.json" ] || exit 0

version=""
if [ -n "${INSPIRE_FACTORY_ROOT:-}" ]; then
  version="$(jq -r '.version // empty' "$INSPIRE_FACTORY_ROOT/orchestrator/package.json" 2>/dev/null)"
fi

# ponytail: dotted numeric versions only; a pre-release tag would need a real semver compare
at_least() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]; }

if [ -z "$version" ]; then
  printf '%s\n' ".inspire/emanate.json found, and the Factory's version cannot be read (set INSPIRE_FACTORY_ROOT to its checkout)." \
    "Do not move its keys under \`factory\` until the Factory is $MIN or later: an older Factory refuses that section."
  exit 1
fi
if at_least "$version" "$MIN"; then
  printf '%s\n' ".inspire/emanate.json found. Factory $version reads \`factory:\` in .inspire/emanate.yml." \
    "Run /inspire-config init to move the keys and delete the old file."
  exit 0
fi
printf '%s\n' ".inspire/emanate.json found, and Factory $version is older than $MIN." \
  "Do not move its keys under \`factory\` yet: this Factory refuses that section and no longer finds its settings once the old file is gone. Update the Factory first."
exit 1
