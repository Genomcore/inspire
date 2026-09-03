#!/usr/bin/env bash
# Empty-array expansion under bash 3.2 + set -u.
# Moved from test-upgrade.sh:103-115.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

# ---- empty-array expansion under bash 3.2 + set -u -----------------------
# manifest_versions yielding nothing (no manifests present, no lock hint)
# must not crash the calling script with an unbound-variable error — it must
# return the documented rc=1.
noman_w="$(mktemp -d)"
noman_plugin="$noman_w/plugin"; mkdir -p "$noman_plugin/manifests"
noman_proj="$noman_w/proj"; mkdir -p "$noman_proj"
noman_err="$(detect_version "$noman_plugin" "$noman_proj" 2>&1 >/dev/null)"; noman_rc=$?
eq "empty manifests dir returns rc=1, not a crash" "$noman_rc" "1"
check "empty manifests dir does not raise an unbound-variable error" \
  "! printf '%s' \"\$noman_err\" | grep -qi 'unbound variable'"
fixture_cleanup "$noman_w"

summary
