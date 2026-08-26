#!/usr/bin/env bash
# seed_kb's additive contract, through 00_bootstrap/glossary.md.
# Moved from test-materialize.sh:446-506.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

# The released baseline this block detects against — why a v0.6.0 fixture and
# not the current tree is spelled out in 01-init-current-tree.sh.
FIXTURE_VERSION="0.6.0"
FIXTURE_MANIFEST="$PLUGIN_ROOT/manifests/$FIXTURE_VERSION.json"
FIXTURE_WORK="$(mktemp -d)"
# The tag is spelled out: run.sh greps these call sites for what to pre-build.
FIXTURE_BASE="$(fixture_from_tag v0.6.0 "$FIXTURE_WORK" "$REPO")"
# fixture_copy <dest> — a private copy of the baseline, for one block to mutate.
fixture_copy() { mkdir -p "$1" && cp -R "$FIXTURE_BASE/." "$1/"; }

# ---------------------------------------------------------------------------
# 00_bootstrap/glossary.md is the KB file this release adds, so it is the one
# file that exercises seed_kb's additive contract in both directions at once.
# A project that predates it — every project upgrading INTO this release — must
# RECEIVE it from an update; a project that already authored one must KEEP its
# bytes. Removing the seeded copy and re-running update drives the exact code
# path a cross-version upgrade takes (seed_kb runs unconditionally in both
# modes, materialize.sh:963, and its "already on disk" branch adds only what is
# missing beneath an existing layer); the genuine cross-version proof, on a
# v0.6.0 fixture, lives in test-upgrade.sh's fake-root section.
# ---------------------------------------------------------------------------
#
# The init half stays on the current tree — init never detects, and "does THIS
# release's init seed the file" is the question. Both update directions run on
# their own v0.6.0 fixture copy: they detect, and a v0.6.0 KB genuinely predates
# the file, so direction 1 became the real cross-version proof rather than a
# delete-and-recreate against the same tree it was seeded from.
gl="$(mktemp -d)/glproj"; mkdir -p "$gl"; ( cd "$gl" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$gl" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "GLOSSARY: seeded by init" \
  "[ -f '$gl/inspire_kb/00_bootstrap/glossary.md' ]"
# Ships EMPTY — header + separator and no data row. That is R4's no-op
# condition, so the shape is the assertion, not merely the file's presence.
check "GLOSSARY: ships with zero data rows" \
  "[ \"\$(grep -c '^|' '$gl/inspire_kb/00_bootstrap/glossary.md')\" = 2 ]"
rm -rf "$(dirname "$gl")"

# Direction 1 — a project from BEFORE the file existed receives it from an
# update. The premise is asserted, because a baseline that already carried the
# file would make the direction vacuous.
gl1="$(mktemp -d)/gl1"
fixture_copy "$gl1"
check "GLOSSARY: premise — the v$FIXTURE_VERSION baseline predates the file" \
  "[ ! -f '$gl1/inspire_kb/00_bootstrap/glossary.md' ]"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$gl1" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "GLOSSARY: an update seeds it into a project that lacks it" \
  "[ -f '$gl1/inspire_kb/00_bootstrap/glossary.md' ]"
check "GLOSSARY: what the update seeded has zero data rows too" \
  "[ \"\$(grep -c '^|' '$gl1/inspire_kb/00_bootstrap/glossary.md')\" = 2 ]"
rm -rf "$(dirname "$gl1")"

# Direction 2 — an operator's own glossary is never replaced. Assert on the
# BYTES: "the file exists afterwards" passes even if update overwrote it with
# the skeleton, which is precisely the failure this guards against. Its own
# fixture copy, because an update already run is an update that has reconciled
# the project to the current tree.
gl2="$(mktemp -d)/gl2"
fixture_copy "$gl2"
printf -- '# Glossary\n\n| Term | Rejected synonyms | Definition |\n|---|---|---|\n| tenant | organization, workspace | The billing account. |\n' \
  > "$gl2/inspire_kb/00_bootstrap/glossary.md"
gl_before="$(shasum -a 256 "$gl2/inspire_kb/00_bootstrap/glossary.md" | cut -d' ' -f1)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$gl2" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "GLOSSARY: an operator's own glossary survives update byte-identical" \
  "[ '$gl_before' = \"\$(shasum -a 256 '$gl2/inspire_kb/00_bootstrap/glossary.md' | cut -d' ' -f1)\" ]"
check "GLOSSARY: the operator's own row is still there" \
  "grep -q 'organization, workspace' '$gl2/inspire_kb/00_bootstrap/glossary.md'"
rm -rf "$(dirname "$gl2")"

fixture_cleanup "$FIXTURE_WORK"
summary
