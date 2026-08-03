#!/usr/bin/env bash
# Tests plugin/scripts/materialize.sh against a scratch project.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
PLUGIN_ROOT="$HERE/.."
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
pass=0; fail=0
ok()   { echo "PASS $1"; pass=$((pass+1)); }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

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
# Must run BEFORE the --skip test below: an update with --skip rebaselines the lock to
# the drifted hash, after which a re-plan would correctly report it as unchanged.
drift="$proj/.claude/skills/inspire-domain/SKILL.md"
printf '\nLOCAL EDIT\n' >> "$drift"
rm -f "$proj/.inspire/bin/no-todos.sh"
lock_before="$(shasum -a 256 "$proj/.inspire.lock" | cut -d' ' -f1)"
dc_err="$(mktemp)"
dc="$("$SCRIPT" --mode drift-check --plugin-root "$PLUGIN_ROOT" --project-root "$proj" 2>"$dc_err")"
lock_after="$(shasum -a 256 "$proj/.inspire.lock" | cut -d' ' -f1)"
check "drift-check parses"             "printf '%s' \"\$dc\" | jq -e . >/dev/null"
check "drift-check finds the edit"     "grep -q 'SKILL.md.*you changed it, we did not' '$dc_err'"
check "drift-check finds the deletion" "grep -q 'no-todos.sh.*restoring at the new version' '$dc_err'"
check "drift-check lists unchanged"    "[ \"\$(printf '%s' \"\$dc\" | jq '.verdicts.noop')\" -gt 0 ]"
check "drift-check is read-only"       "[ '$lock_before' = \"\$lock_after\" ]"
rm -f "$dc_err"
# Restore the deleted validator so the --skip test below starts from a known state.
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype \
  --skip .claude/skills/inspire-domain/SKILL.md >/dev/null 2>&1
check "missing file restored"          "[ -x '$proj/.inspire/bin/no-todos.sh' ]"

# --skip must not overwrite a drifted file.
before="$(shasum -a 256 "$drift" | cut -d' ' -f1)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype \
  --skip .claude/skills/inspire-domain/SKILL.md >/dev/null 2>&1
after="$(shasum -a 256 "$drift" | cut -d' ' -f1)"
check "SKIPPED FILE UNTOUCHED"        "[ '$before' = '$after' ]"

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
kbp="$(mktemp -d)/kbproj"; mkdir -p "$kbp"; ( cd "$kbp" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$kbp" \
  --source-root source --prototype-root prototype >/dev/null 2>&1

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
check "KB regression: no KB files added or removed by update" \
  "[ \"\$kb_count_before\" = \"\$kb_count_after\" ]"
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
# reached migration step 5 (`rm .inspire.lock`) without doing step 1
# (`git mv`), or never had a lock. Unguarded, init exits 0 reporting a clean
# install while the entire knowledge base sits at .inspire_kb/, a path no v0.3
# skill reads, with an empty inspire_kb/ seeded beside it.
# ---------------------------------------------------------------------------
um="$(mktemp -d)/umproj"; mkdir -p "$um/.inspire_kb/03_features"; ( cd "$um" && git init -q )
printf -- '# Login\n\nThe real, only copy.\n' > "$um/.inspire_kb/03_features/feat-login.md"
umerr="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$um" \
  --source-root source --prototype-root prototype 2>&1 >/dev/null)"
rc_um=$?
check "unmigrated v0.2: init exits 1"                 "[ '$rc_um' = 1 ]"
check "unmigrated v0.2: names the git mv step"        "printf '%s' \"\$umerr\" | grep -q 'git mv .inspire_kb inspire_kb'"
check "unmigrated v0.2: no empty KB seeded beside it" "[ ! -e '$um/inspire_kb' ]"
check "unmigrated v0.2: nothing written at all"       "[ ! -d '$um/.claude/skills' ] && [ ! -f '$um/.inspire.lock' ]"
check "unmigrated v0.2: the old KB is untouched"      "[ -f '$um/.inspire_kb/03_features/feat-login.md' ]"

# Once step 1 is done the guard must stand down — otherwise it blocks the very
# migration it prescribes.
( cd "$um" && mv .inspire_kb inspire_kb )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$um" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
rc_um2=$?
check "migrated v0.2: init now succeeds"              "[ '$rc_um2' = 0 ]"
check "migrated v0.2: the migrated KB survives it"    "[ -f '$um/inspire_kb/03_features/feat-login.md' ] && grep -q 'The real, only copy' '$um/inspire_kb/03_features/feat-login.md'"
check "migrated v0.2: skeleton filled in around it"   "[ -f '$um/inspire_kb/03_features/README.md' ] && [ -f '$um/inspire_kb/99_tracker/README.md' ]"
rm -rf "$(dirname "$um")"

# ---------------------------------------------------------------------------
# A .gitignore rule that shadows the materialized runtime must be REPORTED.
# 0.2's install.sh wrote `/.claude` (the runtime was regenerated, never
# committed); 0.3 inverts that — .claude/skills/ and .claude/inspire/hooks/
# must be committed so the runtime travels with the repo. An appended
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
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$gp" \
  --skip '.claude/skills/../../../ESCAPE' >/dev/null 2>&1
rc_traverse=$?
check "guard: --skip containing .. is rejected" "[ '$rc_traverse' = 1 ]"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$gp" \
  --skip '/etc/passwd' >/dev/null 2>&1
rc_abs=$?
check "guard: absolute --skip is rejected"      "[ '$rc_abs' = 1 ]"

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

# The guard must not fire on a real v0.3 lock — a false positive here would
# break every legitimate update. Needs its own sandbox: $proj is gone by now.
okp="$(mktemp -d)/proj"; mkdir -p "$okp"; ( cd "$okp" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$okp" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
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

echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
