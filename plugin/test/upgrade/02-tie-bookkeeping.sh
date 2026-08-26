#!/usr/bin/env bash
# N-way tie bookkeeping (Task 5 review findings).
# Moved from test-upgrade.sh:71-102.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

# ---- N-way tie bookkeeping (Task 5 review findings) ---------------------
# A single min/max pair can only ever remember one runner-up, so a 3+-way tie
# would silently drop all but one contender. Build synthetic manifests in a
# scratch plugin_root — plugin/manifests/ is never touched.
tie_w="$(mktemp -d)"
tie_plugin="$tie_w/plugin"; mkdir -p "$tie_plugin/manifests"
tie_proj="$tie_w/proj"; mkdir -p "$tie_proj"
printf 'shared\n' > "$tie_proj/shared.txt"
tie_h="$(sha256_of "$tie_proj/shared.txt")"

# Three candidates, all scoring 100%, spanning two DIFFERENT layouts (A, A, B).
jq -n --arg h "$tie_h" '{version:"1.0.0",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.0.0.json"
jq -n --arg h "$tie_h" '{version:"1.0.1",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.0.1.json"
jq -n --arg h "$tie_h" '{version:"2.0.0",released:"x",commit:"x",layout:"B",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/2.0.0.json"

tie_err="$(detect_version "$tie_plugin" "$tie_proj" 2>&1 >/dev/null)"; tie_rc=$?
eq "N-way cross-layout tie is refused (rc)" "$tie_rc" "1"
check "N-way cross-layout tie mentions all three candidates" \
  "printf '%s' \"\$tie_err\" | grep -q '1.0.0' && printf '%s' \"\$tie_err\" | grep -q '1.0.1' && printf '%s' \"\$tie_err\" | grep -q '2.0.0'"

# Same three-candidate shape, but all SAME layout: must still resolve, to the
# highest version — a same-layout tie is the normal, safe case.
rm -f "$tie_plugin/manifests/2.0.0.json"
jq -n --arg h "$tie_h" '{version:"1.5.0",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.5.0.json"
eq "N-way same-layout tie resolves to the highest version" \
  "$(detect_version "$tie_plugin" "$tie_proj" 2>/dev/null | cut -f1)" "1.5.0"
fixture_cleanup "$tie_w"

summary
