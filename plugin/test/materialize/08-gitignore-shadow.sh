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

# No false positive on a clean repo: no entry of the INSPIRE block is a payload
# class root or a shipped file, so none may ever trip the warning.
nsh="$(mktemp -d)/nshproj"; mkdir -p "$nsh"; ( cd "$nsh" && git init -q )
nshout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$nsh" \
  --source-root source --prototype-root prototype 2>/dev/null)"
check "gitignore shadow: no false positive on a clean repo" \
  "[ \"\$(printf '%s' \"\$nshout\" | jq -r '.warnings | length')\" = 0 ]"
check "gitignore shadow: the block's own worktrees line shadows no class" \
  "grep -qxF '.claude/worktrees/' '$nsh/.gitignore' && [ -z \"\$(git -C '$nsh' check-ignore --no-index .claude/skills .claude/agents)\" ]"

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
check "gitignore shadow: a shadowed class root is told to remove the rule" \
  "printf '%s' \"\$agshout\" | jq -r '.warnings[]' | grep -q 'remove it by hand'"

# A Node project's `dist/` rule above the INSPIRE block: the block's negation
# re-includes the visor plugins' dist/ and the project's own dist/ stays ignored.
nod="$(mktemp -d)/nodproj"; mkdir -p "$nod"; ( cd "$nod" && git init -q )
printf 'dist/\n' > "$nod/.gitignore"
nodout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$nod" \
  --source-root source --prototype-root prototype 2>/dev/null)"
check "gitignore shadow: a dist/ rule above the block leaves the plugin's dist/ committed" \
  "{ git -C '$nod' check-ignore --no-index .inspire/visor/plugins/inspire/dist/index.js >/dev/null; [ \$? = 1 ]; }"
check "gitignore shadow: and the project's own dist/ stays ignored" \
  "git -C '$nod' check-ignore -q --no-index dist/app.js"
check "gitignore shadow: and nothing is warned about" \
  "[ \"\$(printf '%s' \"\$nodout\" | jq -r '.warnings | length')\" = 0 ]"

# Per shipped file, below a root that is not ignored: a `dist/` rule BELOW the
# block wins over its negation and drops the visor plugin's dist/index.js.
dsh="$(mktemp -d)/dshproj"; mkdir -p "$dsh"; ( cd "$dsh" && git init -q )
printf '# --- INSPIRE (materialize.sh) ---\n.claude/settings.local.json\n# --- end INSPIRE ---\ndist/\n' > "$dsh/.gitignore"
dshout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$dsh" \
  --source-root source --prototype-root prototype 2>"$dsh/.stderr")"
dsh_line="$(grep -nx 'dist/' "$dsh/.gitignore" | cut -d: -f1)"
check "gitignore shadow: the visor root is NOT ignored (premise)" \
  "! git -C '$dsh' check-ignore -q --no-index .inspire/visor"
check "gitignore shadow: a dist/ rule is warned about, naming the shipped file" \
  "printf '%s' \"\$dshout\" | jq -r '.warnings[]' | grep -q '.inspire/visor/plugins/inspire/dist/index.js'"
check "gitignore shadow: the stderr block names its source rule" \
  "grep -q '.inspire/visor/plugins/inspire/dist/index.js  (.gitignore:$dsh_line:dist/)' '$dsh/.stderr'"
check "gitignore shadow: a shadowed file is told to add a negation, not to remove the rule" \
  "printf '%s' \"\$dshout\" | jq -r '.warnings[]' | grep 'dist/index.js' | grep -q 'negation' && ! printf '%s' \"\$dshout\" | jq -r '.warnings[]' | grep -q 'remove it by hand'"

rm -rf "$(dirname "$shp")" "$(dirname "$nsh")" "$(dirname "$agsh")" "$(dirname "$nod")" "$(dirname "$dsh")"

summary
