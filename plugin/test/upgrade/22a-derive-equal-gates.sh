#!/usr/bin/env bash
# The derive-equal branch: what the two gates refuse.
# Cut from upgrade/22-derive-equal-e2e.sh:24-58 (test-upgrade.sh:1690-1724).
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

MZ="$PLUGIN_ROOT/scripts/materialize.sh"

# The version-patched fake plugin root of test-upgrade.sh:1575-1592, which
# pins this block's TARGET at 0.7.0 whatever plugin.json says next.
fake7="$(mktemp -d)"
cp -R "$PLUGIN_ROOT/." "$fake7/plugin"
jq '.version="0.7.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  > "$fake7/plugin/.claude-plugin/plugin.json"
FP7="$fake7/plugin"
seeds7="$HERE/fixtures/retired-seeds"

# ---- the derive-equal branch, end to end -----------------------------------
# The branch a pristine fixture can never exercise: two real hubs, a registry
# whose rows are exactly their derivation (in reverse order, one row
# backticked, one carrying display text — so the equality is normalized and
# order-insensitive, not byte-lucky), and the seed's own prose around the
# table. Both gates hold → all three indexes retire, no questions.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
printf -- '---\nkind: module-hub\nprefix: AUTH              # the module'"'"'s feature / use-case ID prefix\n---\n\n# Auth\n' \
  > "$p/inspire_kb/02_modules/auth.md"
printf -- '---\nkind: module-hub\nprefix: BILL\n---\n\n# Billing\n' \
  > "$p/inspire_kb/02_modules/billing.md"
h7_reg="$p/inspire_kb/02_modules/_index.md"
grep -v '_e\.g\._' "$h7_reg" > "$h7_reg.tmp" && mv "$h7_reg.tmp" "$h7_reg"
printf '| Billing | `BILL` | [[billing]] |\n| Auth | AUTH | [[auth|Auth]] |\n' >> "$h7_reg"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
eq "derive-equal: hub-backed rows behind pristine prose retire silently" \
   "$(printf '%s' "$h7_plan" | jq -cr '[.verdicts.delete, (.ask|length)]')" "[3,0]"

# BLOCKER-1 regression: authored prose around a PERFECTLY-synced table is
# content the row compare cannot see — the non-row gate must route it to ask.
printf '\nTeam note: check with Ops before renaming modules.\n' >> "$h7_reg"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
eq "derive-equal is gated on pristine prose: an added note asks instead" \
   "$(printf '%s' "$h7_plan" | jq -cr '[.verdicts.delete, .ask]')" \
   '[2,["inspire_kb/02_modules/_index.md"]]'

# BLOCKER-2 regression: zero hubs and a deleted example row must not compare
# "equal to nothing" and retire — nothing to derive from is not a proof.
rm -f "$p/inspire_kb/02_modules/auth.md" "$p/inspire_kb/02_modules/billing.md"
grep -v '_e\.g\._' "$seeds7/02_modules__index.md" > "$h7_reg"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
eq "an empty derivation proves nothing: table-less registry asks" \
   "$(printf '%s' "$h7_plan" | jq -cr '[.verdicts.delete, .ask]')" \
   '[2,["inspire_kb/02_modules/_index.md"]]'
fixture_cleanup "$w"
rm -rf "$fake7"

summary
