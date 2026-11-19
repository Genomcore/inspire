#!/usr/bin/env bash
# .inspire/bin/scaffold.sh
#
# Tool, not a review rule: lays a seed's starter project under the source root of a
# repository that has no code yet. `/inspire-config stack` runs it when the operator
# takes a seed, and `/inspire:init` runs it for the default seed when the operator
# keeps the defaults, so a project reaches its first INSPIRE Factory run with a tree
# the units build on. Nothing else creates one.
#
# Usage: scaffold.sh [--dry-run] <seed>
#        scaffold.sh --list
#
# A seed is `.inspire/seeds/<seed>/files/`, copied as it stands. `seed.json` beside it
# may name `copy`: files of the installed runtime the starter needs in its own tree
# (`{"from": "<project-relative path>", "to": "<path under the source root>"}`).
#
# It refuses, and writes nothing, when:
#   · the source root is `.` — the repository root is the code, so there is code;
#   · the source root holds anything but a README.md — a project with code is never
#     scaffolded over.
#
# No file of the project's is ever replaced. The one file it does replace is INSPIRE's
# own: the README.md stub `/inspire:init` seeds in the source root, recognized by its
# first line. A README.md the project wrote stays, and the starter's is not copied.
#
# It installs no dependency and starts nothing: the starter's own README says how.
#
# stdout: one line per file: `create <path>`, `replace <path>` (the stub) or `keep <path>`.
# exit:   0 scaffolded (or would be, with --dry-run) · 1 refused or misused
#
# Config (env, optional): SDD_SOURCE_ROOT · SDD_SEEDS_ROOT (default .inspire/seeds).

set -uo pipefail

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$_LIB_DIR/_lib.sh"

SEEDS_ROOT="${SDD_SEEDS_ROOT:-.inspire/seeds}"
DRY_RUN=0
SEED=""

die() { printf 'scaffold.sh: %s\n' "$1" >&2; exit 1; }
seeds() { [ -d "$SEEDS_ROOT" ] && find "$SEEDS_ROOT" -mindepth 2 -maxdepth 2 -type d -name files | sed "s#^$SEEDS_ROOT/##; s#/files\$##" | sort; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --list) seeds; exit 0 ;;
    -*) die "unknown flag '$1'" ;;
    *) [ -z "$SEED" ] || die "one seed at a time (got '$SEED' and '$1')"; SEED="$1" ;;
  esac
  shift
done

[ -n "$SEED" ] || die "usage: scaffold.sh [--dry-run] <seed> — seeds: $(seeds | paste -sd' ' -)"
case "$SEED" in */*|.*) die "'$SEED' is not a seed id" ;; esac
FILES="$SEEDS_ROOT/$SEED/files"
[ -d "$FILES" ] || die "no seed '$SEED' under $SEEDS_ROOT — seeds: $(seeds | paste -sd' ' -)"

ROOT="$SDD_SOURCE_ROOT"
case "$ROOT" in
  .|./) die "source_root is '.': the repository root is the code, and a project with code is never scaffolded" ;;
  /*|*..*) die "source_root '$ROOT' leaves the repository" ;;
esac
if [ -d "$ROOT" ]; then
  other="$(find "$ROOT" -mindepth 1 -maxdepth 1 ! -name README.md | head -5)"
  [ -z "$other" ] || die "$ROOT/ already holds code ($(printf '%s' "$other" | paste -sd' ' -)…): a project with code is never scaffolded"
fi

# Everything the starter copies from the runtime must be there before the first write.
META="$SEEDS_ROOT/$SEED/seed.json"
copies=""
if [ -f "$META" ]; then
  copies="$(jq -r '.copy // [] | .[] | "\(.from)\t\(.to)"' "$META")" || die "$META is not valid JSON"
  while IFS="$(printf '\t')" read -r from to; do
    [ -n "$from" ] || continue
    [ -f "$from" ] || die "seed '$SEED' needs $from, which is not installed"
    case "$to" in /*|*..*) die "$META copies to '$to', outside the source root" ;; esac
  done <<EOF
$copies
EOF
fi

STUB_HEADING='# `/source` — the production monorepo'

put() { # <source file> <path under the source root>
  if [ "$2" = "README.md" ] && [ -f "$ROOT/$2" ] && [ "$(head -n 1 "$ROOT/$2")" = "$STUB_HEADING" ]; then
    printf 'replace %s\n' "$ROOT/$2"
  elif [ -e "$ROOT/$2" ]; then
    printf 'keep %s\n' "$ROOT/$2"; return 0
  else
    printf 'create %s\n' "$ROOT/$2"
  fi
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$(dirname "$ROOT/$2")" && cp "$1" "$ROOT/$2"
}

while IFS= read -r f; do
  put "$f" "${f#"$FILES"/}" || die "could not write $ROOT/${f#"$FILES"/}"
done < <(find "$FILES" -type f | LC_ALL=C sort)

while IFS="$(printf '\t')" read -r from to; do
  [ -n "$from" ] || continue
  put "$from" "$to" || die "could not write $ROOT/$to"
done <<EOF
$copies
EOF
