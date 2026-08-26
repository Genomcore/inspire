#!/usr/bin/env bash
# The same seeding contract for 00_bootstrap/semantic-types.md.
# Moved from test-materialize.sh:507-557.
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
# 00_bootstrap/semantic-types.md is the KB file T3 adds (a project's own
# semantic-type vocabulary), so it earns the same seeding coverage as
# glossary.md above: init seeds it, a pre-T3 project receives it from an
# update, and an operator's own copy survives update untouched. The source
# side is asserted first — the skeleton must actually exist in the shipped
# plugin, or "seeded by init" below would pass vacuously against a stale
# destination left by an earlier run.
# ---------------------------------------------------------------------------
check "SEMANTIC-TYPES: shipped in the plugin skeleton" \
  "[ -f '$PLUGIN_ROOT/base/kb/00_bootstrap/semantic-types.md' ]"

st="$(mktemp -d)/stproj"; mkdir -p "$st"; ( cd "$st" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$st" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "SEMANTIC-TYPES: seeded by init" \
  "[ -f '$st/inspire_kb/00_bootstrap/semantic-types.md' ]"
# Ships EMPTY, same shape as glossary.md: header + separator, zero data rows.
check "SEMANTIC-TYPES: ships with zero data rows" \
  "[ \"\$(grep -c '^|' '$st/inspire_kb/00_bootstrap/semantic-types.md')\" = 2 ]"
rm -rf "$(dirname "$st")"

# Direction 1 — a project from BEFORE the file existed receives it from an
# update. The premise is asserted, because a baseline that already carried the
# file would make the direction vacuous.
st1="$(mktemp -d)/st1"
fixture_copy "$st1"
check "SEMANTIC-TYPES: premise — the v$FIXTURE_VERSION baseline predates the file" \
  "[ ! -f '$st1/inspire_kb/00_bootstrap/semantic-types.md' ]"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$st1" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "SEMANTIC-TYPES: an update seeds it into a project that lacks it" \
  "[ -f '$st1/inspire_kb/00_bootstrap/semantic-types.md' ]"
rm -rf "$(dirname "$st1")"

# Direction 2 — an operator's own semantic-types.md is never replaced. Assert
# on the BYTES: "the file exists afterwards" passes even if update overwrote
# it with the skeleton, which is precisely the failure this guards against.
st2="$(mktemp -d)/st2"
fixture_copy "$st2"
printf -- '# Semantic types\n\n| Type | Base type | Means / predicate | Rendering |\n|---|---|---|---|\n| money | integer | Minor units, never a float | — |\n' \
  > "$st2/inspire_kb/00_bootstrap/semantic-types.md"
st_before="$(shasum -a 256 "$st2/inspire_kb/00_bootstrap/semantic-types.md" | cut -d' ' -f1)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$st2" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "SEMANTIC-TYPES: an operator's own file survives update byte-identical" \
  "[ '$st_before' = \"\$(shasum -a 256 '$st2/inspire_kb/00_bootstrap/semantic-types.md' | cut -d' ' -f1)\" ]"
check "SEMANTIC-TYPES: the operator's own row is still there" \
  "grep -q 'Minor units, never a float' '$st2/inspire_kb/00_bootstrap/semantic-types.md'"
rm -rf "$(dirname "$st2")"

fixture_cleanup "$FIXTURE_WORK"
summary
