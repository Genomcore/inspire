#!/usr/bin/env bash
# The derive-equal branch, end to end.
# Moved from test-upgrade.sh:1690-1960.
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

# Pristine seeds, REAL plugin root (the T2-deferred swap, landed post-bump):
# plan predicts 3 silent deletes and no questions, writes nothing (record/act
# parity, files AND directories), and the subsequent real update lands exactly
# the predicted split — the three files disappear and NOTHING else does, while
# the release's new reference files arrive as creates (sampled by name, never
# counted). The premise is asserted first: on drifted fixture seeds every
# retire-verdict below would pass for the wrong reason.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.6.0 "$w" "$REPO")"
h7_pristine=0
for h7_pair in \
  "inspire_kb/02_modules/_index.md:02_modules__index.md" \
  "inspire_kb/05_screens/patterns/_index.md:05_screens-patterns__index.md" \
  "inspire_kb/05_screens/components/_index.md:05_screens-components__index.md"; do
  [ "$(sha256_of "$p/${h7_pair%%:*}")" = "$(sha256_of "$seeds7/${h7_pair#*:}")" ] \
    && h7_pristine=$((h7_pristine+1))
done
eq "premise: the v0.6.0 fixture carries all three seeds pristine" "$h7_pristine" "3"

h7_before_f="$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
h7_before_d="$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"
h7_list_before="$(cd "$p" && find . -type f | LC_ALL=C sort)"
h7_plan_log="$(mktemp)"
h7_plan="$(bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>"$h7_plan_log")"
h7_rc=$?
eq "real-root plan exits 0" "$h7_rc" "0"
check "plan's chain reaches 0.7.0 from the shipped manifest" \
  "[ \"\$(printf '%s' \"\$h7_plan\" | jq -r '.chain|index(\"0.7.0\")')\" != null ]"
# The release's new reference files show up as creates — sampled BY NAME (one
# per family: a split skill's reference, the shared capture reference, a second
# split skill), never a count or tree enumeration.
check "plan names the new references as creates (sampled by name)" \
  "grep -q 'create   .claude/skills/inspire-module/references/module-review.md' '$h7_plan_log' && \
   grep -q 'create   .claude/skills/_references/lesson-capture.md' '$h7_plan_log' && \
   grep -q 'create   .claude/skills/inspire-screens/references/screen-validate.md' '$h7_plan_log'"
eq "plan predicts exactly the 3 retirements (delete count)" \
   "$(printf '%s' "$h7_plan" | jq -r '.verdicts.delete')" "3"
eq "plan predicts no questions (merged ask count)" \
   "$(printf '%s' "$h7_plan" | jq -r '.verdicts.ask')" "0"
eq "plan predicts no questions (ask[])" \
   "$(printf '%s' "$h7_plan" | jq -r '.ask|length')" "0"
check "plan names all three retirements in the post-hop space" \
  "grep -q 'delete   inspire_kb/02_modules/_index.md' '$h7_plan_log' && \
   grep -q 'delete   inspire_kb/05_screens/patterns/_index.md' '$h7_plan_log' && \
   grep -q 'delete   inspire_kb/05_screens/components/_index.md' '$h7_plan_log'"
eq "plan wrote no file" "$h7_before_f" \
   "$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "plan removed no directory" "$h7_before_d" \
   "$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"

h7_up="$(bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" 2>/dev/null)"
h7_rc=$?
eq "real-root update exits 0" "$h7_rc" "0"
check "the three retired indexes are gone" \
  "[ ! -e '$p/inspire_kb/02_modules/_index.md' ] && \
   [ ! -e '$p/inspire_kb/05_screens/patterns/_index.md' ] && \
   [ ! -e '$p/inspire_kb/05_screens/components/_index.md' ]"
# Record/act parity on the whole tree: the set of files that DISAPPEARED is
# exactly the set the plan predicted — additions (lock, log, seeds) are the
# update's normal business and are not losses.
h7_lost="$(comm -23 <(printf '%s\n' "$h7_list_before") <(cd "$p" && find . -type f | LC_ALL=C sort))"
eq "only the three predicted files disappeared" "$h7_lost" \
"./inspire_kb/02_modules/_index.md
./inspire_kb/05_screens/components/_index.md
./inspire_kb/05_screens/patterns/_index.md"
eq "update leaves no question open" \
   "$(printf '%s' "$h7_up" | jq -r '.ask|length')" "0"
eq "the lock stamps 0.7.0" "$(jq -r .inspire_version "$p/.inspire.lock")" "0.7.0"
check "the lock's template_sha is real (the shipped manifest names the release commit)" \
  "[ \"\$(jq -r .template_sha '$p/.inspire.lock')\" != 'unknown' ]"
# The release does not only RETIRE KB files, it adds two: 00_bootstrap/glossary.md
# and 05_screens/components/.gitkeep, which a v0.6.0 project cannot already have.
# This is the cross-version proof that seed_kb's additive half still runs
# alongside the hop's deletions — asserted on the REAL root, both files by name.
check "the release's new KB file arrived (glossary seeded on upgrade)" \
  "[ -f '$p/inspire_kb/00_bootstrap/glossary.md' ]"
check "the seeded glossary carries the R4-consumable shape, zero data rows" \
  "[ \"\$(grep -c '^|' '$p/inspire_kb/00_bootstrap/glossary.md')\" = 2 ]"
check "the components .gitkeep arrived (the release's second KB seed)" \
  "[ -f '$p/inspire_kb/05_screens/components/.gitkeep' ]"
rm -f "$h7_plan_log"
fixture_cleanup "$w"

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
