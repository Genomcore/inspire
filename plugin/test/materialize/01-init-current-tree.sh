#!/usr/bin/env bash
# init against a scratch project on the current tree.
# Moved from test-materialize.sh:56-281.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

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
# The tag is spelled out: run.sh greps these call sites for what to pre-build.
FIXTURE_BASE="$(fixture_from_tag v0.6.0 "$FIXTURE_WORK" "$REPO")"
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
# The agents payload class. Both sides asserted: a destination check alone
# passes whether or not the copy ran, since an empty .claude/agents/ is a
# perfectly ordinary thing for a project to have.
check "premise: the plugin ships base/agents/"  "[ -f '$PLUGIN_ROOT/base/agents/README.txt' ]"
check "agents materialized"           "[ -f '$proj/.claude/agents/README.txt' ]"
check "the agent payload is byte-identical to what ships" \
  "cmp -s '$PLUGIN_ROOT/base/agents/README.txt' '$proj/.claude/agents/README.txt'"
# Claude Code parses EVERY *.md under .claude/agents/ as an agent definition, so
# a shipped .md without agent frontmatter is a broken agent in every project we
# touch. The class's README is a .txt for exactly that reason; this is the guard
# on everything shipped here later (T9's role shells).
agent_lint() {
  local d="$1" f out=""
  while IFS= read -r f; do
    head -n1 "$f" | grep -q '^---$' || out="$out $(basename "$f"):frontmatter"
    grep -q '^name:' "$f"          || out="$out $(basename "$f"):name"
  done < <(find "$d" -type f -name '*.md')
  printf '%s' "$out"
}
eq "every .md shipped under base/agents carries agent frontmatter" \
   "$(agent_lint "$PLUGIN_ROOT/base/agents")" ""
# Until a .md actually ships here the check above passes over an EMPTY SET,
# which is indistinguishable from coverage. So prove the lint bites: same
# function, a copy of the same directory, one deliberate offender in it.
agl="$(mktemp -d)"; cp -R "$PLUGIN_ROOT/base/agents/." "$agl/"
printf 'no frontmatter here\n' > "$agl/broken.md"
eq "the frontmatter guard bites on a .md that lacks one" \
   "$(agent_lint "$agl")" " broken.md:frontmatter broken.md:name"
rm -rf "$agl"
check "nothing under base/agents is committed executable" \
  "[ -z \"\$(find '$PLUGIN_ROOT/base/agents' -type f -perm -u+x)\" ]"
check "and none of it acquired the executable bit on the way in" \
  "[ -z \"\$(find '$proj/.claude/agents' -type f -perm -u+x)\" ]"
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
# Directories included: a payload class whose root the preview created would be
# a write, however empty the directory looked afterwards.
check "dry-run creates no .claude/agents either" "[ ! -e '$clean/.claude/agents' ]"

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

fixture_cleanup "$FIXTURE_WORK"
summary
