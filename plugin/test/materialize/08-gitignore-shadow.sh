#!/usr/bin/env bash
# A .gitignore rule that shadows the materialized runtime is reported.
# Moved from test-materialize.sh:688-759.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

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

# Per payload class, not per .claude/. A rule that excludes ONLY the agents root
# leaves every other class committed, so the warning must name that root and no
# other — the blanket '/.claude' case above cannot tell a per-class check from a
# hardcoded list of the older three.
agsh="$(mktemp -d)/agshproj"; mkdir -p "$agsh"; ( cd "$agsh" && git init -q )
printf '.claude/agents/\n' > "$agsh/.gitignore"
agshout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$agsh" \
  --source-root source --prototype-root prototype 2>/dev/null)"
check "gitignore shadow: agents really is ignored (premise)" \
  "git -C '$agsh' check-ignore -q --no-index .claude/agents"
check "gitignore shadow: skills is NOT ignored (premise)" \
  "! git -C '$agsh' check-ignore -q --no-index .claude/skills"
check "gitignore shadow: an agents-only rule is warned about" \
  "printf '%s' \"\$agshout\" | jq -r '.warnings[]' | grep -q '.claude/agents'"
check "gitignore shadow: and it names only the class that is shadowed" \
  "! printf '%s' \"\$agshout\" | jq -r '.warnings[]' | grep -q '.claude/skills'"

rm -rf "$(dirname "$shp")" "$(dirname "$nsh")" "$(dirname "$agsh")"

summary
