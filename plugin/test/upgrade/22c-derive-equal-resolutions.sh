#!/usr/bin/env bash
# The derive-equal branch: questions, and the flags that answer them.
# Cut from upgrade/22-derive-equal-e2e.sh:142-232 (test-upgrade.sh:1808-1898).
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

# A diverged registry and a project-created ADR index are QUESTIONS, in the
# plan and in an unresolved update alike — and the unresolved default keeps
# both files while the two provably-pristine TOCs still retire around them.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
printf '| Auth | `AUTH` | [[auth]] |\n' >> "$p/inspire_kb/02_modules/_index.md"
printf '# ADR index\n' > "$p/inspire_kb/01_adr/_index.md"
h7_reg_sha="$(sha256_of "$p/inspire_kb/02_modules/_index.md")"
h7_adr_sha="$(sha256_of "$p/inspire_kb/01_adr/_index.md")"
h7_plan_log="$(mktemp)"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>"$h7_plan_log")"
eq "diverged plan asks about both files (ask[])" \
   "$(printf '%s' "$h7_plan" | jq -r '.ask|sort|join(" ")')" \
   "inspire_kb/01_adr/_index.md inspire_kb/02_modules/_index.md"
eq "diverged plan's merged ask count agrees" \
   "$(printf '%s' "$h7_plan" | jq -r '.verdicts.ask')" "2"
eq "the two pristine TOCs still retire around the questions" \
   "$(printf '%s' "$h7_plan" | jq -r '.verdicts.delete')" "2"
check "the footer counts the same two decisions" \
  "grep -q '2 decision(s) needed' '$h7_plan_log'"
h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
check "unresolved update keeps the diverged registry and the ADR index" \
  "[ -f '$p/inspire_kb/02_modules/_index.md' ] && [ -f '$p/inspire_kb/01_adr/_index.md' ]"
# Kept means BYTE-untouched, not merely present — "keep" that rewrites is the
# failure the whole default exists to rule out.
eq "the kept registry is byte-identical" \
   "$(sha256_of "$p/inspire_kb/02_modules/_index.md")" "$h7_reg_sha"
eq "the kept ADR index is byte-identical" \
   "$(sha256_of "$p/inspire_kb/01_adr/_index.md")" "$h7_adr_sha"
eq "both questions are still open in the update's ask[]" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|sort|join(" ")')" \
   "inspire_kb/01_adr/_index.md inspire_kb/02_modules/_index.md"
check "the persisted report carries the ASK rows" \
  "grep -q 'ASK      inspire_kb/02_modules/_index.md' '$p/.inspire/last-upgrade.log' && \
   grep -q 'ASK      inspire_kb/01_adr/_index.md' '$p/.inspire/last-upgrade.log'"
rm -f "$h7_plan_log"
fixture_cleanup "$w"

# --take-base retires the diverged file on the operator's word (journalled as
# the delete it is), and a misspelled path warns on BOTH channels — warnings[]
# and stderr — because silent-keep is exactly what a typo would otherwise look
# like.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
printf '| Auth | `AUTH` | [[auth]] |\n' >> "$p/inspire_kb/02_modules/_index.md"
h7_up_log="$(mktemp)"
h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" \
         --take-base inspire_kb/02_modules/_index.md \
         --take-base inspire_kb/02_moduelz/_index.md 2>"$h7_up_log")"
h7_rc=$?
eq "update with --take-base exits 0" "$h7_rc" "0"
check "--take-base retired the diverged registry" \
  "[ ! -e '$p/inspire_kb/02_modules/_index.md' ]"
check "the resolution is journalled as the delete it became" \
  "grep -q 'delete   inspire_kb/02_modules/_index.md' '$p/.inspire/last-upgrade.log'"
eq "no question stays open once resolved" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|length')" "0"
eq "exactly the misspelled path warns in warnings[]" \
   "$(printf '%s' "$h7_up" | jq -r '[.warnings[]|select(contains("matched nothing"))]|length')" "1"
check "the warning names the misspelled path, not the consumed one" \
  "printf '%s' \"\$h7_up\" | jq -r '.warnings[]' | grep 'matched nothing' | grep -q '02_moduelz'"
check "the same warning reached stderr" \
  "grep -q '02_moduelz.*matched nothing' '$h7_up_log'"
rm -f "$h7_up_log"
fixture_cleanup "$w"

# --take-mine keeps — and it must be journalled as a keep even when the
# verdict would have retired the file silently (the pristine patterns TOC
# here): a consumed resolution must appear in the journal under SOME verb, or
# the unmatched-resolution warning would fire about an answer that was
# honoured (the contract pinned in _warn_unmatched_resolutions).
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
printf '| Auth | `AUTH` | [[auth]] |\n' >> "$p/inspire_kb/02_modules/_index.md"
h7_reg_sha="$(sha256_of "$p/inspire_kb/02_modules/_index.md")"
h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" \
         --take-mine inspire_kb/02_modules/_index.md \
         --take-mine inspire_kb/05_screens/patterns/_index.md 2>/dev/null)"
check "--take-mine kept the diverged registry" \
  "[ -f '$p/inspire_kb/02_modules/_index.md' ]"
eq "--take-mine kept it byte-identical" \
   "$(sha256_of "$p/inspire_kb/02_modules/_index.md")" "$h7_reg_sha"
check "--take-mine kept the pristine TOC the verdict would have retired" \
  "[ -f '$p/inspire_kb/05_screens/patterns/_index.md' ]"
check "the unresolved pristine TOC still retired around them" \
  "[ ! -e '$p/inspire_kb/05_screens/components/_index.md' ]"
check "both keeps are journalled as the operator's instruction" \
  "grep -q 'keep     inspire_kb/02_modules/_index.md.*your instruction' '$p/.inspire/last-upgrade.log' && \
   grep -q 'keep     inspire_kb/05_screens/patterns/_index.md.*your instruction' '$p/.inspire/last-upgrade.log'"
eq "a consumed resolution is not an open question" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|length')" "0"
eq "a consumed resolution draws no unmatched warning" \
   "$(printf '%s' "$h7_up" | jq -r '[.warnings[]|select(contains("matched nothing"))]|length')" "0"
fixture_cleanup "$w"
rm -rf "$fake7"

summary
