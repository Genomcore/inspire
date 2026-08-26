#!/usr/bin/env bash
# The derive-equal branch: pre-0.3 parity, record then act.
# Cut from upgrade/22-derive-equal-e2e.sh:234-292 (test-upgrade.sh:1900-1958).
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

# Pre-0.3 parity — the case the whole root-resolution design exists for. In
# record mode the 0.3.0 hop has journalled its moves but NOT performed them
# (hop_mv's record branch returns before the mv), so when this hop is sourced
# in the same ascending pass the KB is still at .inspire_kb/ — yet every path
# it journals must already be in the POST-hop space, or the plan's ask[] hands
# the operator a path no --take-* flag could ever match. The act run then has
# to land exactly the split the record run predicted.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.1.0 "$w" "$REPO")"
h7_pristine=0
for h7_pair in \
  ".inspire_kb/02_modules/_index.md:02_modules__index.md" \
  ".inspire_kb/05_screens/patterns/_index.md:05_screens-patterns__index.md" \
  ".inspire_kb/05_screens/components/_index.md:05_screens-components__index.md"; do
  [ "$(sha256_of "$p/${h7_pair%%:*}")" = "$(sha256_of "$seeds7/${h7_pair#*:}")" ] \
    && h7_pristine=$((h7_pristine+1))
done
eq "premise: the v0.1.0 fixture carries all three seeds pristine at .inspire_kb" \
   "$h7_pristine" "3"
h7_before_f="$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
h7_before_d="$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"
h7_kb_before="$(cd "$p/.inspire_kb" && find . -type f | LC_ALL=C sort)"
h7_plan_log="$(mktemp)"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$FP7" --project-root "$p" 2>"$h7_plan_log")"
h7_rc=$?
eq "pre-0.3 fake-root plan exits 0" "$h7_rc" "0"
eq "the chain runs 0.3.0 then 0.7.0 in one pass" \
   "$(printf '%s' "$h7_plan" | jq -cr '.chain')" '["0.3.0","0.7.0"]'
eq "pre-0.3 plan predicts no questions" \
   "$(printf '%s' "$h7_plan" | jq -r '.ask|length')" "0"
check "the predicted retirements are in the POST-hop path space" \
  "grep -q 'delete   inspire_kb/02_modules/_index.md' '$h7_plan_log' && \
   grep -q 'delete   inspire_kb/05_screens/patterns/_index.md' '$h7_plan_log' && \
   grep -q 'delete   inspire_kb/05_screens/components/_index.md' '$h7_plan_log'"
check "no retirement leaks the pre-hop path space" \
  "! grep -q 'delete   \.inspire_kb/' '$h7_plan_log'"
eq "pre-0.3 plan wrote no file" "$h7_before_f" \
   "$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "pre-0.3 plan removed no directory" "$h7_before_d" \
   "$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"

h7_up="$(bash "$MZ" --mode update --plugin-root "$FP7" --project-root "$p" 2>/dev/null)"
h7_rc=$?
eq "pre-0.3 fake-root update exits 0" "$h7_rc" "0"
check "the KB moved and the old root is gone" \
  "[ -d '$p/inspire_kb' ] && [ ! -e '$p/.inspire_kb' ]"
# Same subtree, same comparison as the 0.6.0 case: within the KB, the act run
# lost exactly what the record run predicted — the rename is factored out by
# comparing the two roots' relative trees, and seed additions are not losses.
h7_lost="$(comm -23 <(printf '%s\n' "$h7_kb_before") <(cd "$p/inspire_kb" && find . -type f | LC_ALL=C sort))"
eq "the KB lost exactly the three predicted files, nothing else" "$h7_lost" \
"./02_modules/_index.md
./05_screens/components/_index.md
./05_screens/patterns/_index.md"
eq "pre-0.3 update leaves no question open" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|length')" "0"
eq "the lock stamps 0.7.0 after the longest chain" \
   "$(jq -r .inspire_version "$p/.inspire.lock")" "0.7.0"
rm -f "$h7_plan_log"
fixture_cleanup "$w"
rm -rf "$fake7"

summary
