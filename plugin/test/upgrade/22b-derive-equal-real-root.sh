#!/usr/bin/env bash
# The derive-equal branch on pristine seeds and the REAL plugin root.
# Cut from upgrade/22-derive-equal-e2e.sh:60-140 (test-upgrade.sh:1726-1806).
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

MZ="$PLUGIN_ROOT/scripts/materialize.sh"
seeds7="$HERE/fixtures/retired-seeds"

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
# Derived, not literal: this file runs against the REAL plugin root, a moving
# target, and a pinned version asserts nothing the root's own does not.
eq "the lock stamps the current release" \
   "$(jq -r .inspire_version "$p/.inspire.lock")" \
   "$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")"
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

summary
