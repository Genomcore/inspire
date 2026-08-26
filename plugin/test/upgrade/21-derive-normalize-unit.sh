#!/usr/bin/env bash
# Unit: the derive/normalize layer, driven directly.
# Moved from test-upgrade.sh:1620-1689.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/hop-ops.sh"

# ---- unit: the derive/normalize layer, driven directly --------------------
# Sourcing the hop against an empty project performs no operation (neither KB
# root exists, so every per-file driver skips) and leaves the _h7_* helpers
# defined for direct calls — the same direct-drive precedent as the
# hop_ops_init/run_chain section above. The doctrine hop_report is the one
# journal row a no-op source produces.
u7="$(mktemp -d)"; mkdir -p "$u7/proj"
unset HOP_JOURNAL
hop_ops_init "$u7/proj" /dev/null 1
. "$PLUGIN_ROOT/scripts/hops/0.7.0.sh"
eq "sourcing against an empty project journals nothing but the doctrine note" \
   "$(awk -F'\t' '$1!="report"' "$HOP_JOURNAL" | wc -l | tr -d ' ')" "0"

eq "norm: backticks and whitespace runs are presentation" \
   "$(printf '|  Auth  |  `AUTH`  |  [[auth]]  |\n' | _h7_norm_rows)" \
   "| Auth | AUTH | [[auth]] |"
eq "norm: wikilink display text is presentation" \
   "$(printf '| Auth | AUTH | [[auth|Auth]] |\n' | _h7_norm_rows)" \
   "| Auth | AUTH | [[auth]] |"
eq "norm: CR line endings are presentation" \
   "$(printf '| Auth | AUTH | [[auth]] |\r\n' | _h7_norm_rows)" \
   "| Auth | AUTH | [[auth]] |"
eq "norm: duplicate rows survive to diverge (no sort -u)" \
   "$(printf '| A | A | [[a]] |\n| A | A | [[a]] |\n' | _h7_norm_rows | wc -l | tr -d ' ')" "2"

# The separator filter is shape-based: |---| rows (alignment colons included)
# drop; the canonical header drops; a row of EMPTY cells and a reshaped header
# both SURVIVE into the row-set, where they diverge and ask — the filter must
# never eat content, because everything it eats is invisible to the compare.
cat > "$u7/reg.md" <<'EOF'
# Modules — registry

| Module | Prefix | Hub |
|--------|--------|-----|
| Auth | `AUTH` | [[auth]] |
| :--- | ---: | - |
|  |  |  |
| Hub | Module | Prefix |
EOF
eq "disk rows: separators and header drop; empty-cell and reshaped rows survive" \
   "$(_h7_disk_rows "$u7/reg.md")" \
"| Auth | AUTH | [[auth]] |
| Hub | Module | Prefix |
| | | |"

mkdir -p "$u7/hubs"
printf -- '---\nkind: module-hub\nprefix: AUTH              # trailing comment must strip\n---\n\n# Auth\n' > "$u7/hubs/auth.md"
printf -- '---\nprefix: `BILL`\n---\n\n# Billing\n' > "$u7/hubs/billing.md"
printf 'never a hub\n' > "$u7/hubs/_template.md"
printf 'never a hub\n' > "$u7/hubs/README.md"
eq "derive: H1 + prefix per hub; comment stripped; backticks normalized; _* and README skipped" \
   "$(_h7_derive_registry "$u7/hubs")" \
"| Auth | AUTH | [[auth]] |
| Billing | BILL | [[billing]] |"

mkdir -p "$u7/noh1"
printf -- '---\nprefix: X\n---\nno heading here\n' > "$u7/noh1/x.md"
_h7_derive_registry "$u7/noh1" >/dev/null 2>&1
eq "derive: a hub missing its H1 is not provable (rc 1)" "$?" "1"

mkdir -p "$u7/nopfx"
printf -- '---\nkind: module-hub\n---\n\n# X\n' > "$u7/nopfx/x.md"
_h7_derive_registry "$u7/nopfx" >/dev/null 2>&1
eq "derive: a hub missing its prefix is not provable (rc 1)" "$?" "1"

mkdir -p "$u7/nohubs"
_h7_derive_registry "$u7/nohubs" >/dev/null 2>&1
eq "derive: zero hubs prove nothing (rc 1)" "$?" "1"
rm -rf "$u7"

summary
