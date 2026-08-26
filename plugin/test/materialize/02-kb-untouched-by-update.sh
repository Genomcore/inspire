#!/usr/bin/env bash
# Regression: update must never touch inspire_kb/.
# Moved from test-materialize.sh:282-445.
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
# Regression: /inspire:update must never touch inspire_kb/ — the KB is
# product content, not runtime. The historical bug: `--mode update` treated
# each top-level KB layer directory as an INSPIRE-owned entry and `rm -rf`'d
# it before recopying the skeleton, silently destroying anything a project
# authored after init (drift-check never caught it, because it only walks
# paths recorded in .inspire.lock, and the KB was never in there once
# authored). Populate every layer with realistic content, then update
# exactly the way update/SKILL.md tells the skill to — drift-check first,
# --skip each drifted path — and assert nothing under inspire_kb/ moved.
# ---------------------------------------------------------------------------
#
# On a v0.6.0 fixture, for the reason in the baseline note: this block ends in
# an `update`, and an update identifies the project first. That also makes it a
# genuine cross-version run rather than a same-version no-op — which is what an
# operator's `/inspire:update` actually is.
kbp="$(mktemp -d)/kbproj"
fixture_copy "$kbp"

# Author realistic project content across several KB layers.
mkdir -p "$kbp/inspire_kb/02_modules/billing"
printf -- '# Billing module\n\nOwns invoicing and payment capture.\n' \
  > "$kbp/inspire_kb/02_modules/billing/module.md"

mkdir -p "$kbp/inspire_kb/04_domain/billing/invoice"
printf -- '# Invoice\n\nfields:\n  - id\n  - amount\n' \
  > "$kbp/inspire_kb/04_domain/billing/invoice/invoice.md"

printf -- '# ADR-0099: Use event sourcing for invoices\n\nStatus: accepted\n' \
  > "$kbp/inspire_kb/01_adr/adr-0099-event-sourcing.md"

printf -- '---\nid: 20260715_example-lesson\nskill: inspire-domain\ncategory: preference\n---\nAlways validate invoice totals against line items.\n' \
  > "$kbp/inspire_kb/98_lessons/20260715_example-lesson.md"

mkdir -p "$kbp/inspire_kb/99_tracker/tickets"
printf -- '# TICKET-001: Add refund flow\n\nStatus: open\n' \
  > "$kbp/inspire_kb/99_tracker/tickets/TICKET-001.md"

printf -- '\n## Project accent\n\nOur real design system diverges here.\n' \
  >> "$kbp/inspire_kb/05_screens/design-system.md"

adr_before="$(shasum -a 256 "$kbp/inspire_kb/01_adr/adr-0099-event-sourcing.md" | cut -d' ' -f1)"
module_before="$(shasum -a 256 "$kbp/inspire_kb/02_modules/billing/module.md" | cut -d' ' -f1)"
domain_before="$(shasum -a 256 "$kbp/inspire_kb/04_domain/billing/invoice/invoice.md" | cut -d' ' -f1)"
lesson_before="$(shasum -a 256 "$kbp/inspire_kb/98_lessons/20260715_example-lesson.md" | cut -d' ' -f1)"
ticket_before="$(shasum -a 256 "$kbp/inspire_kb/99_tracker/tickets/TICKET-001.md" | cut -d' ' -f1)"
design_before="$(shasum -a 256 "$kbp/inspire_kb/05_screens/design-system.md" | cut -d' ' -f1)"
kb_count_before="$(find "$kbp/inspire_kb" -type f | wc -l | tr -d ' ')"
kb_list_before="$(mktemp)"
( cd "$kbp/inspire_kb" && find . -type f | LC_ALL=C sort ) > "$kb_list_before"

# What a cross-version update OWES this KB: seed_kb is strictly additive, so the
# arithmetic is exactly "every skeleton file base/kb ships that this baseline
# lacks, and nothing else". Deriving it from the tree rather than naming a
# number keeps the assertion true across releases — a v0.6.0 project predates
# both of the files this release adds, and the next release will add others.
kb_seeds_owed=""
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  [ -f "$kbp/inspire_kb/$rel" ] || kb_seeds_owed="$kb_seeds_owed$rel "
done < <(cd "$PLUGIN_ROOT/base/kb" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
kb_seeds_n="$(printf '%s' "$kb_seeds_owed" | wc -w | tr -d ' ')"
check "premise: the baseline predates at least one KB seed this release ships" \
  "[ '$kb_seeds_n' -gt 0 ]"

# What a cross-version update may REMOVE: the chain's hops retire the KB seeds
# they can prove pristine. From a v0.6.0 baseline that is the 0.7.0 hop's three
# index mirrors — asserted pristine here FIRST, so the silent-retire branch
# below fires for the right reason (an edited copy would ask and stay instead).
kb_retire_n=0
for kb_pair in \
  "02_modules/_index.md:02_modules__index.md" \
  "05_screens/components/_index.md:05_screens-components__index.md" \
  "05_screens/patterns/_index.md:05_screens-patterns__index.md"; do
  [ "$(shasum -a 256 "$kbp/inspire_kb/${kb_pair%%:*}" 2>/dev/null | cut -d' ' -f1)" = \
    "$(shasum -a 256 "$HERE/fixtures/retired-seeds/${kb_pair#*:}" | cut -d' ' -f1)" ] \
    && kb_retire_n=$((kb_retire_n+1))
done
check "premise: the baseline carries all three retire-candidates pristine" \
  "[ '$kb_retire_n' = 3 ]"

# Also drift a runtime file and delete another, so the update call below
# mirrors a real operator run against a divergent runtime.
#
# drift-check is now a deprecated alias for --mode plan (Task 12): it
# classifies rather than flatly listing every path whose hash differs from
# the lock, so its only per-path list is `.ask` — reserved for genuine 3-way
# conflicts (both the operator and this INSPIRE release changed the same
# path). An edit with no upstream change classifies `keep`, never `ask` (see
# the block above), so it can no longer be discovered by round-tripping
# `.ask` into --skip the way this test used to. Re-wiring `update` itself to
# consult classify()/keepset_of() instead of an explicit --skip list is
# Task 13's job; this test only needs the one path it itself just edited, so
# it is named directly.
printf '\nLOCAL EDIT\n' >> "$kbp/.claude/skills/inspire-domain/SKILL.md"
rm -f "$kbp/.inspire/bin/no-todos.sh"

dc_kb="$("$SCRIPT" --mode drift-check --plugin-root "$PLUGIN_ROOT" --project-root "$kbp" 2>/dev/null)"
check "KB regression: drift-check names no inspire_kb path" \
  "! (printf '%s' \"\$dc_kb\" | jq -r '.ask[]' | grep -q '^inspire_kb/')"

skip_args=(--skip .claude/skills/inspire-domain/SKILL.md)

"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$kbp" \
  --source-root source --prototype-root prototype "${skip_args[@]}" >/dev/null 2>&1

check "KB regression: ADR in 01_adr survives update" \
  "[ -f '$kbp/inspire_kb/01_adr/adr-0099-event-sourcing.md' ] && [ '$adr_before' = \"\$(shasum -a 256 '$kbp/inspire_kb/01_adr/adr-0099-event-sourcing.md' | cut -d' ' -f1)\" ]"
check "KB regression: module in 02_modules survives update" \
  "[ -f '$kbp/inspire_kb/02_modules/billing/module.md' ] && [ '$module_before' = \"\$(shasum -a 256 '$kbp/inspire_kb/02_modules/billing/module.md' | cut -d' ' -f1)\" ]"
check "KB regression: nested 04_domain descriptor survives update" \
  "[ -f '$kbp/inspire_kb/04_domain/billing/invoice/invoice.md' ] && [ '$domain_before' = \"\$(shasum -a 256 '$kbp/inspire_kb/04_domain/billing/invoice/invoice.md' | cut -d' ' -f1)\" ]"
check "KB regression: lesson in 98_lessons survives update" \
  "[ -f '$kbp/inspire_kb/98_lessons/20260715_example-lesson.md' ] && [ '$lesson_before' = \"\$(shasum -a 256 '$kbp/inspire_kb/98_lessons/20260715_example-lesson.md' | cut -d' ' -f1)\" ]"
check "KB regression: ticket in 99_tracker/tickets survives update" \
  "[ -f '$kbp/inspire_kb/99_tracker/tickets/TICKET-001.md' ] && [ '$ticket_before' = \"\$(shasum -a 256 '$kbp/inspire_kb/99_tracker/tickets/TICKET-001.md' | cut -d' ' -f1)\" ]"
check "KB regression: customized design-system.md survives update" \
  "[ -f '$kbp/inspire_kb/05_screens/design-system.md' ] && [ '$design_before' = \"\$(shasum -a 256 '$kbp/inspire_kb/05_screens/design-system.md' | cut -d' ' -f1)\" ]"

kb_count_after="$(find "$kbp/inspire_kb" -type f | wc -l | tr -d ' ')"
# The old form of this assertion — "no KB files added or removed" — was true
# only because the project was init'd from the same tree it then updated from.
# Across versions the honest claim is: the update adds EXACTLY the seeds the
# baseline lacks and removes EXACTLY what the chain's hops provably retire —
# from v0.6.0, the three pristine index mirrors — and nothing else either way.
kb_seeds_missing_after=0
for rel in $kb_seeds_owed; do
  [ -f "$kbp/inspire_kb/$rel" ] || kb_seeds_missing_after=$((kb_seeds_missing_after+1))
done
check "KB regression: every owed KB seed arrived ($kb_seeds_n of them)" \
  "[ '$kb_seeds_missing_after' = 0 ]"
check "KB regression: the release's own new KB seed is one of them" \
  "[ -f '$kbp/inspire_kb/00_bootstrap/glossary.md' ]"
check "KB regression: update added exactly the owed seeds, removed exactly the retired mirrors (count)" \
  "[ \"\$kb_count_after\" = \"\$((kb_count_before + kb_seeds_n - kb_retire_n))\" ]"
# Counts alone cannot see a removal that an addition cancels out, and losing a
# KB file the release did NOT provably retire is the entire failure this block
# exists to catch — so the paths are compared as a set, not just tallied.
kb_lost_list=""
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  [ -f "$kbp/inspire_kb/$rel" ] || kb_lost_list="${kb_lost_list}${rel}
"
done < "$kb_list_before"
kb_lost_sorted="$(printf '%s' "$kb_lost_list" | LC_ALL=C sort | tr '\n' ' ')"
check "KB regression: the only KB files gone are the three the hop provably retired" \
  "[ '$kb_lost_sorted' = './02_modules/_index.md ./05_screens/components/_index.md ./05_screens/patterns/_index.md ' ]"
rm -f "$kb_list_before"
# The lock no longer carries a `files` map at all (Task 13), which is the
# strongest possible form of "no inspire_kb entries in it": there is nothing in
# the lock that could name a KB path, so no future --take-mine round-trip can
# ever be handed one.
check "KB regression: lock names no paths at all" \
  "[ \"\$(jq -r 'has(\"files\")' '$kbp/.inspire.lock')\" = false ]"

# The runtime half of update must still work: a lock-tracked file deleted
# before the run is restored, and a drifted one is left exactly as edited.
check "KB regression: runtime still updates (missing validator restored)" \
  "[ -x '$kbp/.inspire/bin/no-todos.sh' ]"
check "KB regression: drifted skill still skipped, not overwritten" \
  "grep -q 'LOCAL EDIT' '$kbp/.claude/skills/inspire-domain/SKILL.md'"

rm -rf "$(dirname "$kbp")"

fixture_cleanup "$FIXTURE_WORK"
summary
