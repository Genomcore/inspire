#!/usr/bin/env bash
# Tests plugin/scripts/materialize.sh against a scratch project.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/fixtures.sh"
pass=0; fail=0
ok()   { echo "PASS $1"; pass=$((pass+1)); }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# ---------------------------------------------------------------------------
# The released baseline every DETECTING block runs against.
#
# `--mode update` and `--mode drift-check` both begin by identifying the
# project's version, and identification is a fingerprint of the tree against the
# shipped manifests — nothing else, deliberately, since a lock can lie. A
# project built from the CURRENT tree cannot satisfy that premise mid-release:
# the working tree diverges from the last released manifest a little further
# with every commit. Measured on this commit, a current-root init scores exactly
# 50% against manifests/0.6.0.json — the floor itself — and 47% once a block
# edits one manifest-listed file and deletes another, which is a refusal, an
# empty stdout, and a cascade of failures that say nothing about the code under
# test.
#
# A RELEASE-built project has no such drift: v0.6.0 fingerprints 100% against
# its own manifest today and at every future commit, and 97% after those same
# two mutations. So every detecting block runs on a v0.6.0 fixture, exactly as
# test-upgrade.sh does everywhere. The blocks that only ever call `--mode init`
# stay on the current tree: init never detects, and testing init against the
# current tree is the whole point of it.
#
# The builder runs `git archive` plus a full materialize, so it runs ONCE here
# and each block takes a private copy to mutate. Chaining two updates onto one
# copy is deliberately avoided: the first update reconciles the project to the
# current tree, which lands it back on the same 50% knife-edge this exists to
# leave behind.
# ---------------------------------------------------------------------------
FIXTURE_VERSION="0.6.0"
FIXTURE_MANIFEST="$PLUGIN_ROOT/manifests/$FIXTURE_VERSION.json"
FIXTURE_WORK="$(mktemp -d)"
FIXTURE_BASE="$(fixture_from_tag "v$FIXTURE_VERSION" "$FIXTURE_WORK" "$REPO")"
check "fixture: the v$FIXTURE_VERSION baseline built" \
  "[ -n '$FIXTURE_BASE' ] && [ -f '$FIXTURE_BASE/.inspire.lock' ] && [ -d '$FIXTURE_BASE/inspire_kb' ]"
check "fixture: its manifest ships, so detection has something to match" \
  "[ -f '$FIXTURE_MANIFEST' ]"

# fixture_copy <dest> — a private copy of the baseline, for one block to mutate.
fixture_copy() { mkdir -p "$1" && cp -R "$FIXTURE_BASE/." "$1/"; }

proj="$(mktemp -d)/proj"; mkdir -p "$proj"
( cd "$proj" && git init -q )

# Pre-existing user content that must survive — the regression this replaces.
mkdir -p "$proj/.claude/skills/my-own-skill"
printf -- '---\ndescription: mine\n---\nbody\n' > "$proj/.claude/skills/my-own-skill/SKILL.md"
printf '{"permissions":{"allow":["Bash(ls:*)"]},"enabledPlugins":{"other@thing":true}}\n' > "$proj/.claude/settings.json"

out="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
        --source-root source --prototype-root prototype --declare-marketplace 2>/dev/null)"

check "emits parseable JSON"          "printf '%s' \"\$out\" | jq -e . >/dev/null"
check "reports mode init"             "[ \"\$(printf '%s' \"\$out\" | jq -r .mode)\" = init ]"
check "kb materialized"               "[ -d '$proj/inspire_kb/00_bootstrap' ]"
check "validators materialized"       "[ -x '$proj/.inspire/bin/review.sh' ]"
check "test/ EXCLUDED"                "[ ! -e '$proj/.inspire/bin/test' ]"
check "dispatcher materialized"       "[ -x '$proj/.claude/inspire/hooks/dispatch.sh' ]"
check "skills materialized"           "[ -d '$proj/.claude/skills/inspire-domain' ]"
check "shared _references present"    "[ -d '$proj/.claude/skills/_references' ]"
check "USER SKILL PRESERVED"          "[ -f '$proj/.claude/skills/my-own-skill/SKILL.md' ]"
check "FOREIGN SETTINGS PRESERVED"    "jq -e '.permissions.allow[0]' '$proj/.claude/settings.json' >/dev/null"
check "marker present"                "grep -q INSPIRE-MANAGED '$proj/.claude/settings.json'"
check "one PreToolUse command"        "[ \"\$(jq '[.hooks.PreToolUse[].hooks[]]|length' '$proj/.claude/settings.json')\" = 1 ]"
check "marketplace declared"          "jq -e '.extraKnownMarketplaces.inspire' '$proj/.claude/settings.json' >/dev/null"
check "settings still parses"         "jq -e . '$proj/.claude/settings.json' >/dev/null"
check "enabledPlugins is a record"      "[ \"\$(jq -r '.enabledPlugins|type' '$proj/.claude/settings.json')\" = object ]"
check "enabledPlugins names the plugin" "jq -e '.enabledPlugins[\"inspire@inspire\"] == true' '$proj/.claude/settings.json' >/dev/null"
check "foreign enabledPlugins survive"  "jq -e '.enabledPlugins[\"other@thing\"] == true' '$proj/.claude/settings.json' >/dev/null"
# Read the expected version from the manifest rather than hardcoding it: the
# assertion is "the lock records what the plugin says it is", not "the plugin
# is at some particular version", and a literal here goes stale on every bump.
manifest_version="$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")"
check "lock records the manifest version" "[ \"\$(jq -r .inspire_version '$proj/.inspire.lock')\" = '$manifest_version' ]"
# The per-file `files` map is GONE (Task 13). Drift is derived from
# plugin/manifests/<version>.json now — a baseline that ships with the plugin,
# cannot be rebaselined by a --take-mine, and exists for versions installed
# before the lock ever carried hashes. Two baselines would mean two disagreeing
# answers to "what did we ship?", so the lock must not carry one at all.
check "lock carries NO file hashes"   "[ \"\$(jq -r 'has(\"files\")' '$proj/.inspire.lock')\" = false ]"
# template_sha used to be the hardcoded literal "unknown", which inspire-lesson
# then stamped onto every lesson in every project. It now comes from the
# manifest's commit for the installed version.
check "lock carries a real template_sha" \
  "[ \"\$(jq -r .template_sha '$proj/.inspire.lock')\" = \"\$(jq -r .commit '$PLUGIN_ROOT/manifests/$manifest_version.json')\" ]"
check "design system seeded"          "[ -f '$proj/inspire_kb/05_screens/design-system.md' ]"
check "product roots created"         "[ -d '$proj/source' ] && [ -d '$proj/prototype' ]"
check "no template hook leaked"       "[ -z \"\$(find '$proj/.claude' -name 'template-*.sh')\" ]"
check "CLAUDE.md seeded"              "[ -f '$proj/CLAUDE.md' ]"
check "CLAUDE.md is the stub"         "grep -q 'Provisional stub' '$proj/CLAUDE.md'"
check ".gitignore created"            "[ -f '$proj/.gitignore' ]"
check ".gitignore ignores settings.local.json" "grep -qF '.claude/settings.local.json' '$proj/.gitignore'"

# Directory shipping is a GIT property, not a working-tree one: git tracks
# files only, so a base/kb directory whose last tracked file was deleted still
# exists in the checkout that deleted it while a fresh clone ships without it —
# and seed_kb can only materialize what exists. The 0.7.0 seed retirement
# emptied 05_screens/components/ exactly this way (kept only by a .gitkeep,
# precedent 99_tracker/tickets/.gitkeep). Two halves, or either goes vacuous:
# every on-disk base/kb directory must hold at least one TRACKED file, and
# every tracked base/kb directory must have materialized into the project.
kb_untracked_dirs=0
while IFS= read -r d; do
  rel="${d#"$PLUGIN_ROOT"/}"
  [ -n "$(git -C "$PLUGIN_ROOT" ls-files -- "$rel" 2>/dev/null)" ] \
    || kb_untracked_dirs=$((kb_untracked_dirs+1))
done < <(find "$PLUGIN_ROOT/base/kb" -type d)
check "every on-disk base/kb directory ships at least one tracked file" \
  "[ '$kb_untracked_dirs' = 0 ]"
kb_missing_dirs=0
while IFS= read -r d; do
  [ -d "$proj/inspire_kb/$d" ] || kb_missing_dirs=$((kb_missing_dirs+1))
done < <(git -C "$PLUGIN_ROOT" ls-files -- base/kb \
         | sed -e 's|/[^/]*$||' -e 's|^base/kb||' -e 's|^/||' | sort -u)
check "every git-tracked base/kb directory materialized on init" \
  "[ '$kb_missing_dirs' = 0 ]"

# Idempotency: a second init must not duplicate the settings block.
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "idempotent PreToolUse"         "[ \"\$(jq '[.hooks.PreToolUse[].hooks[]]|length' '$proj/.claude/settings.json')\" = 1 ]"
check "idempotent foreign key"        "jq -e '.permissions.allow[0]' '$proj/.claude/settings.json' >/dev/null"

# drift-check is now a deprecated alias for --mode plan (Task 12): it no
# longer emits the old {drifted,missing,unchanged} shape. It classifies
# instead — an edited-but-otherwise-unchanged-upstream file comes back
# `keep` ("you changed it, we did not"), a deleted-but-still-shipped file
# comes back `restore` ("you deleted this; restoring at the new version") —
# both visible in the stderr report, rolled up as counts in the JSON.
#
# It runs on a v0.6.0 FIXTURE, not on the project init'd above: drift-check
# detects, and a current-tree project cannot be identified once this block has
# mutated two of the files the manifest lists (see the baseline note at the top).
#
# The two fixture files are picked at RUN TIME, from the manifest for the
# baseline the project actually is: the verdict under test is "you changed it,
# we did not", so the file must be one this release did not change either. A
# hardcoded pick goes red whenever a release edits that particular file — the
# classifier then honestly says "both changed", and a true statement about the
# release is reported as a false statement about the classifier. The second pick
# is the no-op witness: left untouched, it must stay unmentioned in the report,
# because the report names every path it would act on and nothing else.
dproj="$(mktemp -d)/dproj"
fixture_copy "$dproj"
drift_rel=""
noop_witness=""
while IFS="$(printf '\t')" read -r cand chash; do
  case "$cand" in .claude/skills/*.md) ;; *) continue ;; esac
  src="$PLUGIN_ROOT/base/skills/${cand#.claude/skills/}"
  [ -f "$src" ] && [ -f "$dproj/$cand" ] || continue
  [ "$(shasum -a 256 "$src" | cut -d' ' -f1)" = "$chash" ] || continue
  [ "$(shasum -a 256 "$dproj/$cand" | cut -d' ' -f1)" = "$chash" ] || continue
  if [ -z "$drift_rel" ]; then drift_rel="$cand"; continue; fi
  noop_witness="$cand"
  break
done < <(jq -r '.files | to_entries[] | "\(.key)\t\(.value)"' "$FIXTURE_MANIFEST")
check "dynamic drift fixture found two manifest-pristine candidates" \
  "[ -n '$drift_rel' ] && [ -n '$noop_witness' ]"
check "premise: the validator this block deletes is one the baseline shipped" \
  "jq -e '.files[\".inspire/bin/no-todos.sh\"]' '$FIXTURE_MANIFEST' >/dev/null"
drift="$dproj/$drift_rel"
printf '\nLOCAL EDIT\n' >> "$drift"
drift_edited="$(shasum -a 256 "$drift" | cut -d' ' -f1)"
rm -f "$dproj/.inspire/bin/no-todos.sh"
lock_before="$(shasum -a 256 "$dproj/.inspire.lock" | cut -d' ' -f1)"
dc_err="$(mktemp)"
dc="$("$SCRIPT" --mode drift-check --plugin-root "$PLUGIN_ROOT" --project-root "$dproj" 2>"$dc_err")"
lock_after="$(shasum -a 256 "$dproj/.inspire.lock" | cut -d' ' -f1)"
check "drift-check parses"             "printf '%s' \"\$dc\" | jq -e . >/dev/null"
# The baseline is asserted from the run itself, so a fixture-builder regression
# is loud here rather than mysterious three assertions later.
check "drift-check identified the project as v$FIXTURE_VERSION" \
  "grep -q 'INSPIRE upgrade — $FIXTURE_VERSION' '$dc_err'"
check "drift-check finds the edit"     "grep -q '$drift_rel.*you changed it, we did not' '$dc_err'"
check "drift-check finds the deletion" "grep -q 'no-todos.sh.*restoring at the new version' '$dc_err'"
check "drift-check lists unchanged"    "[ \"\$(printf '%s' \"\$dc\" | jq '.verdicts.noop')\" -gt 0 ]"
check "the untouched pristine file is one of the unchanged (never named)" \
  "! grep -q '$noop_witness' '$dc_err'"
check "drift-check is read-only"       "[ '$lock_before' = \"\$lock_after\" ]"
rm -f "$dc_err"

# One update does both jobs: it restores what the operator deleted and leaves
# what they edited alone. The second update this block used to run is gone on
# purpose — it started from a project the first update had already reconciled to
# the current tree, which is exactly the unidentifiable state the fixture exists
# to avoid.
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$dproj" \
  --source-root source --prototype-root prototype \
  --skip "$drift_rel" >/dev/null 2>&1
check "missing file restored"          "[ -x '$dproj/.inspire/bin/no-todos.sh' ]"
check "SKIPPED FILE UNTOUCHED" \
  "[ '$drift_edited' = \"\$(shasum -a 256 '$drift' | cut -d' ' -f1)\" ]"
rm -rf "$(dirname "$dproj")"

# --dry-run writes nothing.
clean="$(mktemp -d)/p2"; mkdir -p "$clean"; ( cd "$clean" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$clean" \
  --source-root source --prototype-root prototype --dry-run >/dev/null 2>&1
check "dry-run writes nothing"        "[ ! -e '$clean/inspire_kb' ] && [ ! -e '$clean/.inspire.lock' ]"

# Brownfield: '.' and 'none' create no folders.
bf="$(mktemp -d)/p3"; mkdir -p "$bf"; ( cd "$bf" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$bf" \
  --source-root . --prototype-root none >/dev/null 2>&1
check "brownfield creates no source/" "[ ! -e '$bf/source' ] && [ ! -e '$bf/prototype' ]"
check "brownfield still gets kb"      "[ -d '$bf/inspire_kb/00_bootstrap' ]"

# Never-clobber: a pre-existing CLAUDE.md and .gitignore are the operator's —
# CLAUDE.md is left byte-identical, .gitignore is appended-to (not replaced),
# and a second init does not duplicate the appended block.
own="$(mktemp -d)/p4"; mkdir -p "$own"; ( cd "$own" && git init -q )
printf 'MY OWN CLAUDE.md\ndo not touch\n' > "$own/CLAUDE.md"
printf 'node_modules/\n' > "$own/.gitignore"
claude_before="$(shasum -a 256 "$own/CLAUDE.md" | cut -d' ' -f1)"
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$own" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
claude_after="$(shasum -a 256 "$own/CLAUDE.md" | cut -d' ' -f1)"
check "EXISTING CLAUDE.md UNTOUCHED"        "[ '$claude_before' = '$claude_after' ]"
check ".gitignore keeps original line"      "grep -qF 'node_modules/' '$own/.gitignore'"
check ".gitignore gains INSPIRE block"      "grep -qF '.claude/settings.local.json' '$own/.gitignore'"
check ".gitignore block appears once"       "[ \"\$(grep -c 'INSPIRE (materialize.sh)' '$own/.gitignore')\" = 1 ]"

"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$own" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
claude_after2="$(shasum -a 256 "$own/CLAUDE.md" | cut -d' ' -f1)"
check "second init: CLAUDE.md still untouched" "[ '$claude_before' = '$claude_after2' ]"
check "second init: .gitignore block still once" "[ \"\$(grep -c 'INSPIRE (materialize.sh)' '$own/.gitignore')\" = 1 ]"
check "second init: original line survives"     "grep -qF 'node_modules/' '$own/.gitignore'"

rm -rf "$(dirname "$proj")" "$(dirname "$clean")" "$(dirname "$bf")" "$(dirname "$own")"

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
# Across versions the honest claim is narrower and stronger: the update adds
# EXACTLY the seeds the baseline lacks, and removes nothing at all.
kb_seeds_missing_after=0
for rel in $kb_seeds_owed; do
  [ -f "$kbp/inspire_kb/$rel" ] || kb_seeds_missing_after=$((kb_seeds_missing_after+1))
done
check "KB regression: every owed KB seed arrived ($kb_seeds_n of them)" \
  "[ '$kb_seeds_missing_after' = 0 ]"
check "KB regression: the release's own new KB seed is one of them" \
  "[ -f '$kbp/inspire_kb/00_bootstrap/glossary.md' ]"
check "KB regression: update added exactly those seeds, no more" \
  "[ \"\$kb_count_after\" = \"\$((kb_count_before + kb_seeds_n))\" ]"
# Counts alone cannot see a removal that an addition cancels out, and losing a
# KB file is the entire failure this block exists to catch — so the paths are
# compared, not just tallied.
kb_lost=0
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  [ -f "$kbp/inspire_kb/$rel" ] || kb_lost=$((kb_lost+1))
done < "$kb_list_before"
check "KB regression: not one KB file present before the update went missing" \
  "[ '$kb_lost' = 0 ]"
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

# ---------------------------------------------------------------------------
# 00_bootstrap/glossary.md is the KB file this release adds, so it is the one
# file that exercises seed_kb's additive contract in both directions at once.
# A project that predates it — every project upgrading INTO this release — must
# RECEIVE it from an update; a project that already authored one must KEEP its
# bytes. Removing the seeded copy and re-running update drives the exact code
# path a cross-version upgrade takes (seed_kb runs unconditionally in both
# modes, materialize.sh:963, and its "already on disk" branch adds only what is
# missing beneath an existing layer); the genuine cross-version proof, on a
# v0.6.0 fixture, lives in test-upgrade.sh's fake-root section.
# ---------------------------------------------------------------------------
#
# The init half stays on the current tree — init never detects, and "does THIS
# release's init seed the file" is the question. Both update directions run on
# their own v0.6.0 fixture copy: they detect, and a v0.6.0 KB genuinely predates
# the file, so direction 1 became the real cross-version proof rather than a
# delete-and-recreate against the same tree it was seeded from.
gl="$(mktemp -d)/glproj"; mkdir -p "$gl"; ( cd "$gl" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$gl" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "GLOSSARY: seeded by init" \
  "[ -f '$gl/inspire_kb/00_bootstrap/glossary.md' ]"
# Ships EMPTY — header + separator and no data row. That is R4's no-op
# condition, so the shape is the assertion, not merely the file's presence.
check "GLOSSARY: ships with zero data rows" \
  "[ \"\$(grep -c '^|' '$gl/inspire_kb/00_bootstrap/glossary.md')\" = 2 ]"
rm -rf "$(dirname "$gl")"

# Direction 1 — a project from BEFORE the file existed receives it from an
# update. The premise is asserted, because a baseline that already carried the
# file would make the direction vacuous.
gl1="$(mktemp -d)/gl1"
fixture_copy "$gl1"
check "GLOSSARY: premise — the v$FIXTURE_VERSION baseline predates the file" \
  "[ ! -f '$gl1/inspire_kb/00_bootstrap/glossary.md' ]"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$gl1" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "GLOSSARY: an update seeds it into a project that lacks it" \
  "[ -f '$gl1/inspire_kb/00_bootstrap/glossary.md' ]"
check "GLOSSARY: what the update seeded has zero data rows too" \
  "[ \"\$(grep -c '^|' '$gl1/inspire_kb/00_bootstrap/glossary.md')\" = 2 ]"
rm -rf "$(dirname "$gl1")"

# Direction 2 — an operator's own glossary is never replaced. Assert on the
# BYTES: "the file exists afterwards" passes even if update overwrote it with
# the skeleton, which is precisely the failure this guards against. Its own
# fixture copy, because an update already run is an update that has reconciled
# the project to the current tree.
gl2="$(mktemp -d)/gl2"
fixture_copy "$gl2"
printf -- '# Glossary\n\n| Term | Rejected synonyms | Definition |\n|---|---|---|\n| tenant | organization, workspace | The billing account. |\n' \
  > "$gl2/inspire_kb/00_bootstrap/glossary.md"
gl_before="$(shasum -a 256 "$gl2/inspire_kb/00_bootstrap/glossary.md" | cut -d' ' -f1)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$gl2" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
check "GLOSSARY: an operator's own glossary survives update byte-identical" \
  "[ '$gl_before' = \"\$(shasum -a 256 '$gl2/inspire_kb/00_bootstrap/glossary.md' | cut -d' ' -f1)\" ]"
check "GLOSSARY: the operator's own row is still there" \
  "grep -q 'organization, workspace' '$gl2/inspire_kb/00_bootstrap/glossary.md'"
rm -rf "$(dirname "$gl2")"

# ---------------------------------------------------------------------------
# Regression: /inspire:init over a repo that ALREADY has an inspire_kb/ must
# seed around it, never through it. The historical bug: init treated each
# top-level KB layer as an INSPIRE-owned entry and `rm -rf`'d it before
# copying the skeleton, so a restored backup, a KB vendored in before init, a
# hand-deleted lock — and above all the pre-0.3 migration, whose step 4 is
# `rm .inspire.lock` — all walked into total loss of the knowledge base.
# init must add only the layer files the project lacks.
# ---------------------------------------------------------------------------
pre="$(mktemp -d)/preproj"; mkdir -p "$pre"; ( cd "$pre" && git init -q )
mkdir -p "$pre/inspire_kb/00_bootstrap" "$pre/inspire_kb/03_features" \
         "$pre/inspire_kb/04_domain/billing/invoice" "$pre/inspire_kb/01_adr"
printf -- '---\nlanguage: en\n---\n# Our real stack\n' > "$pre/inspire_kb/00_bootstrap/stack.md"
printf -- '# Login\n\nAcceptance: user signs in.\n'      > "$pre/inspire_kb/03_features/feat-login.md"
printf -- '# Invoice\n\nfields:\n  - id\n'               > "$pre/inspire_kb/04_domain/billing/invoice/invoice.md"
printf -- '# ADR-0001: Use Postgres\n\nStatus: accepted\n' > "$pre/inspire_kb/01_adr/adr-0001-postgres.md"

pre_stack_before="$(shasum -a 256 "$pre/inspire_kb/00_bootstrap/stack.md" | cut -d' ' -f1)"
pre_feat_before="$(shasum -a 256 "$pre/inspire_kb/03_features/feat-login.md" | cut -d' ' -f1)"
pre_dom_before="$(shasum -a 256 "$pre/inspire_kb/04_domain/billing/invoice/invoice.md" | cut -d' ' -f1)"
pre_adr_before="$(shasum -a 256 "$pre/inspire_kb/01_adr/adr-0001-postgres.md" | cut -d' ' -f1)"

preout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$pre" \
  --source-root source --prototype-root prototype 2>/dev/null)"

check "PRE-EXISTING KB: authored feature survives init" \
  "[ -f '$pre/inspire_kb/03_features/feat-login.md' ] && [ '$pre_feat_before' = \"\$(shasum -a 256 '$pre/inspire_kb/03_features/feat-login.md' | cut -d' ' -f1)\" ]"
check "PRE-EXISTING KB: nested domain descriptor survives init" \
  "[ -f '$pre/inspire_kb/04_domain/billing/invoice/invoice.md' ] && [ '$pre_dom_before' = \"\$(shasum -a 256 '$pre/inspire_kb/04_domain/billing/invoice/invoice.md' | cut -d' ' -f1)\" ]"
check "PRE-EXISTING KB: authored ADR survives init" \
  "[ -f '$pre/inspire_kb/01_adr/adr-0001-postgres.md' ] && [ '$pre_adr_before' = \"\$(shasum -a 256 '$pre/inspire_kb/01_adr/adr-0001-postgres.md' | cut -d' ' -f1)\" ]"
# stack.md is the one KB file init may still edit — create_product_roots writes
# the answered roots into its frontmatter. It must be AMENDED, never replaced.
check "PRE-EXISTING KB: stack.md keeps its authored body" \
  "grep -q 'Our real stack' '$pre/inspire_kb/00_bootstrap/stack.md'"
check "PRE-EXISTING KB: stack.md gains the answered source_root" \
  "grep -q 'source_root' '$pre/inspire_kb/00_bootstrap/stack.md'"
# Seeding must still fill in what the project lacks, at file granularity.
check "PRE-EXISTING KB: missing file inside an existing layer is seeded" \
  "[ -f '$pre/inspire_kb/03_features/README.md' ]"
check "PRE-EXISTING KB: missing sibling in an existing layer is seeded" \
  "[ -f '$pre/inspire_kb/00_bootstrap/theme.md' ]"
check "PRE-EXISTING KB: wholly absent layer is created" \
  "[ -f '$pre/inspire_kb/99_tracker/README.md' ]"
check "PRE-EXISTING KB: design system still seeded" \
  "[ -f '$pre/inspire_kb/05_screens/design-system.md' ]"

check "PRE-EXISTING KB: reported as an adoption, not a fresh install" \
  "printf '%s' \"\$preout\" | jq -e '.existing_kb == true' >/dev/null"
check "PRE-EXISTING KB: adoption surfaced as a warning" \
  "printf '%s' \"\$preout\" | jq -e '[.warnings[] | select(test(\"already exists\"))] | length > 0' >/dev/null"
# The skill shows a dry run first, so the dry run must reveal the adoption too —
# that plan is the operator's only chance to say no.
predry="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$pre" \
  --source-root source --prototype-root prototype --dry-run 2>/dev/null)"
check "PRE-EXISTING KB: dry run also reports the adoption" \
  "printf '%s' \"\$predry\" | jq -e '.existing_kb == true' >/dev/null"

rm -rf "$(dirname "$pre")"

# A fresh repo must NOT be reported as an adoption.
frk="$(mktemp -d)/frproj"; mkdir -p "$frk"; ( cd "$frk" && git init -q )
frout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$frk" \
  --source-root source --prototype-root prototype 2>/dev/null)"
check "fresh repo: not flagged as an existing KB" \
  "printf '%s' \"\$frout\" | jq -e '.existing_kb == false' >/dev/null"
rm -rf "$(dirname "$frk")"

# ---------------------------------------------------------------------------
# An UNMIGRATED v0.2 tree (.inspire_kb/ present, inspire_kb/ absent) must be
# refused by init. The lock guard cannot catch it: the operator may have
# deleted the lock by hand, or never had one. Unguarded, init exits 0
# reporting a clean install while the entire knowledge base sits at
# .inspire_kb/, a path no v0.3 skill reads, with an empty inspire_kb/ seeded
# beside it. `/inspire:init` never migrates a project in place — the remedy
# is `/inspire:update`, which runs the hop chain this fixture would otherwise
# need by hand.
# ---------------------------------------------------------------------------
um="$(mktemp -d)/umproj"; mkdir -p "$um/.inspire_kb/03_features"; ( cd "$um" && git init -q )
printf -- '# Login\n\nThe real, only copy.\n' > "$um/.inspire_kb/03_features/feat-login.md"
umerr="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$um" \
  --source-root source --prototype-root prototype 2>&1 >/dev/null)"
rc_um=$?
check "unmigrated v0.2: init exits 1"                 "[ '$rc_um' = 1 ]"
check "unmigrated v0.2: points at /inspire:update"    "printf '%s' \"\$umerr\" | grep -q '/inspire:update'"
check "unmigrated v0.2: no empty KB seeded beside it" "[ ! -e '$um/inspire_kb' ]"
check "unmigrated v0.2: nothing written at all"       "[ ! -d '$um/.claude/skills' ] && [ ! -f '$um/.inspire.lock' ]"
check "unmigrated v0.2: the old KB is untouched"      "[ -f '$um/.inspire_kb/03_features/feat-login.md' ]"

# Once the layout is actually moved the guard must stand down — otherwise it
# blocks the very migration it points the operator at.
( cd "$um" && mv .inspire_kb inspire_kb )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$um" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
rc_um2=$?
check "migrated v0.2: init now succeeds"              "[ '$rc_um2' = 0 ]"
check "migrated v0.2: the migrated KB survives it"    "[ -f '$um/inspire_kb/03_features/feat-login.md' ] && grep -q 'The real, only copy' '$um/inspire_kb/03_features/feat-login.md'"
check "migrated v0.2: skeleton filled in around it"   "[ -f '$um/inspire_kb/03_features/README.md' ] && [ -f '$um/inspire_kb/99_tracker/README.md' ]"
rm -rf "$(dirname "$um")"

# ---------------------------------------------------------------------------
# THE PAIR OF REFUSALS ABOVE AND BELOW MUST NOT FORM A CLOSED LOOP. init refuses
# an unmigrated pre-0.3 tree and points at /inspire:update (asserted above);
# update/SKILL.md used to refuse when .inspire.lock was absent, telling the
# operator "this project was never initialized" and sending them to
# /inspire:init. But a pre-0.3 project may legitimately have NO lock — the
# install.sh-era installer wrote one only when both a manifest and jq were
# present, and detection works fine without one (test-upgrade.sh: "detect 0.2.1
# with no lock at all"). So the two instructions pointed at each other with no
# exit, and one of them stated something false about the operator's project.
# Prose is all that was wrong, and prose is what is asserted.
# ---------------------------------------------------------------------------
US="$PLUGIN_ROOT/skills/update/SKILL.md"
check "update skill: exists where the assertions below can see it" "[ -f '$US' ]"
# Grep a FLATTENED copy, not the file: markdown wraps, and the sentence this must
# never say again was itself split across two lines ("this project was never" /
# "initialized — direct the operator to /inspire:init"), so a line-oriented grep
# for it passed even before the fix. Whitespace-squeezed, the claim is visible
# however it is wrapped, and so is a re-worded reintroduction of it.
US_FLAT="$(mktemp)"; tr '\n' ' ' < "$US" | tr -s ' ' > "$US_FLAT"
check "update skill: never claims a missing lock means the project was never initialized" \
  "! grep -qi 'never initialized' '$US_FLAT'"
check "update skill: says the version is identified from disk" \
  "grep -qi 'from what is actually on disk' '$US_FLAT'"
check "update skill: names the legitimate no-lock pre-0.3 case" \
  "grep -qi 'may legitimately have no lock' '$US_FLAT'"
check "update skill: warns that redirecting to init is the closed loop" \
  "grep -qi 'closed loop' '$US_FLAT'"
rm -f "$US_FLAT"

# ---------------------------------------------------------------------------
# A .gitignore rule that shadows the materialized runtime must be REPORTED.
# 0.3 wants .claude/skills/ and .claude/inspire/hooks/ committed, so the runtime
# travels with the repo. INSPIRE never wrote such a rule — `git grep -il gitignore`
# is empty tree-wide at v0.1.0, v0.2.0 and v0.2.1 — so a rule that excludes those
# paths is the project's own (a fork, a template, or the operator). Detection
# still matters; only the earlier claim about WHO wrote it was false. An appended
# `.claude/settings.local.json` cannot re-include what a broader earlier rule
# already excluded (git cannot re-include below an excluded directory), so
# init would otherwise report success while the whole runtime stays invisible
# to git — the headline benefit of 0.3, silently absent.
# ---------------------------------------------------------------------------
shp="$(mktemp -d)/shproj"; mkdir -p "$shp"; ( cd "$shp" && git init -q )
printf '/.claude\nnode_modules/\n' > "$shp/.gitignore"
shout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$shp" \
  --source-root source --prototype-root prototype 2>"$shp/.stderr")"
check "gitignore shadow: runtime really is ignored (premise)" \
  "git -C '$shp' check-ignore -q --no-index .claude/skills"
check "gitignore shadow: reported on stderr" \
  "grep -q 'WARNING' '$shp/.stderr' && grep -qi 'gitignore' '$shp/.stderr'"
check "gitignore shadow: the warning names the shadowed path" \
  "grep 'WARNING' -A6 '$shp/.stderr' | grep -q '.claude/skills'"
check "gitignore shadow: surfaced in the JSON summary" \
  "printf '%s' \"\$shout\" | jq -e '.warnings | length > 0' >/dev/null"
# PROVENANCE. The warning used to say "remove the rule (a 0.2 install wrote
# '/.claude')" — and that text is relayed verbatim to the operator by
# /inspire:update. No INSPIRE release ever wrote a .gitignore line, so it told
# them to delete a line we blamed ourselves for by mistake, in their own file.
# Both the stderr block and the JSON warning are checked: they are two texts.
check "gitignore shadow: the warning does not blame a 0.2 install for the rule" \
  "! grep -qi '0.2 install' '$shp/.stderr' && ! grep -qi \"install.sh wrote\" '$shp/.stderr'"
check "gitignore shadow: the JSON warning does not blame a 0.2 install either" \
  "! printf '%s' \"\$shout\" | jq -r '.warnings[]' | grep -qi '0.2 install'"
check "gitignore shadow: the warning says the rule is not ours" \
  "printf '%s' \"\$shout\" | jq -r '.warnings[]' | grep -q 'INSPIRE did not write this rule'"
check "gitignore shadow: operator's own rules untouched" \
  "grep -qF 'node_modules/' '$shp/.gitignore' && grep -qxF '/.claude' '$shp/.gitignore'"

# The skill shows a dry run first, so the warning must fire there too — that
# plan is the operator's only chance to fix it before anything is written.
shdry="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$shp" \
  --source-root source --prototype-root prototype --dry-run 2>/dev/null)"
check "gitignore shadow: dry run warns before writing" \
  "printf '%s' \"\$shdry\" | jq -e '.warnings | length > 0' >/dev/null"

# No false positive on a clean repo: the INSPIRE block ignores only
# settings.local.json, which must never trip the warning.
nsh="$(mktemp -d)/nshproj"; mkdir -p "$nsh"; ( cd "$nsh" && git init -q )
nshout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$nsh" \
  --source-root source --prototype-root prototype 2>/dev/null)"
check "gitignore shadow: no false positive on a clean repo" \
  "[ \"\$(printf '%s' \"\$nshout\" | jq -r '.warnings | length')\" = 0 ]"

rm -rf "$(dirname "$shp")" "$(dirname "$nsh")"

# ---------------------------------------------------------------------------
# Input guards. Each of these reports SUCCESS while doing the wrong thing if
# its guard is removed — that is why they are here rather than left to review.
# ---------------------------------------------------------------------------

# A --plugin-root that is a directory but not a plugin: every consumer of
# base/ degrades silently, so without the guard this exits 0 having installed
# nothing, and leaves a lock that makes init refuse forever.
gp="$(mktemp -d)/proj"; mkdir -p "$gp"; ( cd "$gp" && git init -q )
notplugin="$(mktemp -d)"
"$SCRIPT" --mode init --plugin-root "$notplugin" --project-root "$gp" >/dev/null 2>&1
rc_notplugin=$?
check "guard: non-plugin --plugin-root exits 1"        "[ '$rc_notplugin' = 1 ]"
check "guard: non-plugin --plugin-root writes no lock" "[ ! -f '$gp/.inspire.lock' ]"
check "guard: non-plugin --plugin-root writes no .gitignore" "[ ! -f '$gp/.gitignore' ]"
check "guard: non-plugin --plugin-root copies nothing" "[ ! -d '$gp/.claude/skills' ]"

# --skip is fed from drift-check echoing the lock's keys verbatim, so a
# corrupted lock must not become an rm -rf outside the project root.
#
# On a v0.6.0 fixture rather than on $gp. $gp carries no runtime at all — the
# init above was refused — so its version cannot be identified and `update`
# exits 1 there whatever --skip says, a BENIGN one included (measured). Both
# assertions passed without the guard ever running. On a project that updates
# cleanly the rc-1 has one remaining explanation, and the benign call below says
# so out loud rather than leaving it implied.
skp="$(mktemp -d)/skproj"
fixture_copy "$skp"
sk_lock_before="$(shasum -a 256 "$skp/.inspire.lock" | cut -d' ' -f1)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$skp" \
  --source-root source --prototype-root prototype \
  --skip '.claude/skills/../../../ESCAPE' >/dev/null 2>&1
rc_traverse=$?
check "guard: --skip containing .. is rejected" "[ '$rc_traverse' = 1 ]"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$skp" \
  --source-root source --prototype-root prototype \
  --skip '/etc/passwd' >/dev/null 2>&1
rc_abs=$?
check "guard: absolute --skip is rejected"      "[ '$rc_abs' = 1 ]"
# A guard that refused after clobbering would still exit 1. It must refuse
# BEFORE anything is written — which is also what leaves the project pristine
# for the control call below, so the three runs differ in their argument alone.
check "guard: a rejected --skip wrote nothing" \
  "[ '$sk_lock_before' = \"\$(shasum -a 256 '$skp/.inspire.lock' | cut -d' ' -f1)\" ]"
# The control: same project, same command, a --skip the guard must accept.
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$skp" \
  --source-root source --prototype-root prototype \
  --skip '.claude/skills/inspire-domain/SKILL.md' >/dev/null 2>&1
rc_benign=$?
check "guard: a benign --skip on the same project exits 0" "[ '$rc_benign' = 0 ]"
rm -rf "$(dirname "$skp")"

# A pre-0.3 *lock* (no `files` map, no actual v0.2 tree behind it — just the
# lock file itself) used to be refused outright by require_v03_lock. Task 12
# deletes that guard on purpose: "a pre-0.3 project is no longer refused, it
# is the longest chain" — detect_version and the hop chain are what decide
# now, not a lock-shape check. This fixture has no real content behind its
# lock, though, so detect_version still refuses it, just for a different
# reason (it cannot identify ANY version from an empty tree) and with a
# different exit code: 1 (precondition failure), not the old 2 (failure
# after writing began — which never applied here anyway, since the old guard
# fired before anything was written).
v2p="$(mktemp -d)/proj"; mkdir -p "$v2p"; ( cd "$v2p" && git init -q )
printf '{"inspire_version":"0.2.1","released":"2026-07-20","template_sha":"abc"}\n' > "$v2p/.inspire.lock"
v2err="$("$SCRIPT" --mode drift-check --plugin-root "$PLUGIN_ROOT" --project-root "$v2p" 2>&1 >/dev/null)"
rc_v2drift=$?
check "guard: pre-0.3 lock — plan can't identify an empty tree (rc)" "[ '$rc_v2drift' = 1 ]"
check "guard: pre-0.3 lock — plan explains why" \
  "printf '%s' \"\$v2err\" | grep -qi 'cannot identify'"
# require_v03_lock's call site inside run_materialize was deleted in Task 12,
# which left `update` running the old blind-copy path for one release: it wrote
# the v0.3 runtime over this fixture, exiting 0, on the strength of nothing but
# a lock file claiming a version. Task 13 wires update through the same
# detect → verify → hop → classify → apply pipeline as `plan`, so the SAME
# refusal now applies to both: an unidentifiable tree is a precondition
# failure, before a byte is written, and the lock is never believed.
#
# These two assertions previously asserted rc = 0 and "the runtime is now on
# disk" — they were tripwires encoding the gap as if it were correct, and they
# had to flip.
v2lock_before="$(shasum -a 256 "$v2p/.inspire.lock" | cut -d' ' -f1)"
v2uerr="$("$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$v2p" 2>&1 >/dev/null)"
rc_v2update=$?
check "guard: pre-0.3 lock — update refuses an unidentifiable tree (rc)" "[ '$rc_v2update' = 1 ]"
check "guard: pre-0.3 lock — update explains why, as plan does" \
  "printf '%s' \"\$v2uerr\" | grep -qi 'cannot identify'"
check "guard: pre-0.3 lock — update wrote no runtime" \
  "[ ! -d '$v2p/.claude/skills' ] && [ ! -d '$v2p/.inspire/bin' ]"
check "guard: pre-0.3 lock — update did not rewrite the lock" \
  "[ '$v2lock_before' = \"\$(shasum -a 256 '$v2p/.inspire.lock' | cut -d' ' -f1)\" ]"
check "guard: pre-0.3 lock — update seeded no KB beside it" "[ ! -e '$v2p/inspire_kb' ]"

# The guard must not fire on a real post-0.3 lock — a false positive here would
# break every legitimate update. A v0.6.0 fixture IS that project: a real
# release, a real lock, and a tree its own manifest identifies at 100%. Init'ing
# from the current tree instead put this pair on the 50% floor, one added
# base/ file away from failing for a reason that has nothing to do with the
# guard under test.
okp="$(mktemp -d)/proj"
fixture_copy "$okp"
"$SCRIPT" --mode drift-check --plugin-root "$PLUGIN_ROOT" --project-root "$okp" >/dev/null 2>&1
rc_okdrift=$?
check "guard: real v0.3 lock still drift-checks" "[ '$rc_okdrift' = 0 ]"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$okp" >/dev/null 2>&1
rc_okupdate=$?
check "guard: real v0.3 lock still updates"      "[ '$rc_okupdate' = 0 ]"
kb_expect="$(find "$PLUGIN_ROOT/base/kb" -type f | wc -l | tr -d ' ')"
check "guard: real v0.3 update kept the KB" \
  "[ \"\$(find '$okp/inspire_kb' -type f | wc -l | tr -d ' ')\" -ge '$kb_expect' ]"

rm -rf "$(dirname "$gp")" "$(dirname "$v2p")" "$(dirname "$okp")" "$notplugin"
fixture_cleanup "$FIXTURE_WORK"

echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
