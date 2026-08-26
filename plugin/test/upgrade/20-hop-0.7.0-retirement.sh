#!/usr/bin/env bash
# The 0.7.0 hop: derive-then-diff index retirement.
# Moved from test-upgrade.sh:1575-1619.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

# ---- the 0.7.0 hop: derive-then-diff index retirement --------------------
# These blocks ran against a version-patched FAKE plugin root while the release
# was being prepared (pre-bump, the real root could never source hops/0.7.0.sh
# and the copied manifests/ had no 0.7.0.json). Since the 0.7.0 bump + manifest
# the patch is a byte-identical no-op — but the FAKE root stays: it pins these
# blocks' TARGET at 0.7.0 regardless of where plugin.json moves next, so they
# survive future bumps unedited. manifests/0.7.0.json ships, the chain comes
# from the main loop (no fallback fires), and write_lock finds the target's
# manifest, so template_sha in these updates is real, never "unknown". The
# end-to-end retirement block below runs on the REAL root — the per-file
# assertions T2 deferred until the hop's effects existed.
fake7="$(mktemp -d)"
cp -R "$PLUGIN_ROOT/." "$fake7/plugin"
jq '.version="0.7.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  > "$fake7/plugin/.claude-plugin/plugin.json"
FP7="$fake7/plugin"
hop7="$PLUGIN_ROOT/scripts/hops/0.7.0.sh"
seeds7="$HERE/fixtures/retired-seeds"

# The blob fixtures pin the hop's constants: the seeds left base/kb in this
# release, so these are the only in-tree copies of the shipped bytes. Each
# constant is read out of the hop file itself — the left side is always a real
# hash, so a renamed or missing constant fails loudly, never vacuously.
eq "modules seed blob matches the hop's pinned constant" \
   "$(sha256_of "$seeds7/02_modules__index.md")" \
   "$(awk -F"'" '/^_h7_sha_modules=/{print $2; exit}' "$hop7")"
eq "patterns seed blob matches the hop's pinned constant" \
   "$(sha256_of "$seeds7/05_screens-patterns__index.md")" \
   "$(awk -F"'" '/^_h7_sha_patterns=/{print $2; exit}' "$hop7")"
eq "components seed blob matches the hop's pinned constant" \
   "$(sha256_of "$seeds7/05_screens-components__index.md")" \
   "$(awk -F"'" '/^_h7_sha_components=/{print $2; exit}' "$hop7")"
# The fourth constant — the seed's NON-ROW remainder, the second gate of the
# derive-equal verdict — pinned the same way, via the same extraction the hop
# itself uses (the exact complement of its row filter).
eq "the modules seed's non-row remainder matches the hop's prose constant" \
   "$(awk '!/^[ \t]*\|/' "$seeds7/02_modules__index.md" | shasum -a 256 | awk '{print $1}')" \
   "$(awk -F"'" '/^_h7_sha_modules_prose=/{print $2; exit}' "$hop7")"
check "the five retired seeds are gone from base/kb (nothing to resurrect)" \
   "[ ! -e '$PLUGIN_ROOT/base/kb/02_modules/_index.md' ] && \
    [ ! -e '$PLUGIN_ROOT/base/kb/05_screens/patterns/_index.md' ] && \
    [ ! -e '$PLUGIN_ROOT/base/kb/05_screens/components/_index.md' ] && \
    [ ! -e '$PLUGIN_ROOT/base/kb/02_modules/_template.md' ] && \
    [ ! -e '$PLUGIN_ROOT/base/kb/06_spikes/_template.md' ]"

rm -rf "$fake7"
summary
