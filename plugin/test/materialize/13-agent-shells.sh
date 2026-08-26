#!/usr/bin/env bash
# The five agent shells: their envelopes on the source side, their arrival on the
# destination side, and the role docs their bodies point at.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

AGENTS="$PLUGIN_ROOT/base/agents"
ROLES="$PLUGIN_ROOT/base/skills/inspire-code/references/roles"
DEPLOYED_ROLES=".claude/skills/inspire-code/references/roles"
PERSONAS="contracter tester implementer"
OVERSEERS="security-overseer quality-overseer"

# fm <file> <key> — a frontmatter value, read from the FIRST block only. The body
# quotes these same words, so a whole-file match would pass on prose alone.
fm() {
  awk -v k="^$2:" 'BEGIN{n=0}
       /^---$/{n++; if(n==2) exit; next}
       n==1 && $0 ~ k { sub(/^[^:]*: */, ""); print; exit }' "$1"
}

# ---------------------------------------------------------------------------
# Source side — identity, envelope, doctrine pointer.
#
# The envelope's tool half lives in this frontmatter and nowhere else: there is
# no path-level write restriction in an agent definition, so an overseer is made
# read-only by what its allowlist omits. Bash is on that list because a shell can
# write, which is the whole reason D3's "writes nothing" needs an allowlist.
# ---------------------------------------------------------------------------
premise "the plugin ships an agents payload class" "[ -d '$AGENTS' ]"
premise "and the role doctrine the shells point at" "[ -d '$ROLES' ]"

for r in $PERSONAS $OVERSEERS; do
  f="$AGENTS/inspire-$r.md"
  check "shell: inspire-$r.md ships" "[ -f '$f' ]"
  [ -f "$f" ] || continue
  nm="$(fm "$f" name)"; ds="$(fm "$f" description)"; tl="$(fm "$f" tools)"
  eq    "shell: inspire-$r declares a name equal to its stem" "$nm" "inspire-$r"
  check "shell: inspire-$r declares a non-empty description"  '[ -n "$ds" ]'
  check "shell: inspire-$r declares a tools allowlist"        '[ -n "$tl" ]'
  check "shell: inspire-$r points at its deployed role doc" \
    "grep -qF '$DEPLOYED_ROLES/$r.md' '$f'"
done

for r in $PERSONAS; do
  has "persona: inspire-$r keeps the Agent tool (D1 self-spawn)" \
      "$(fm "$AGENTS/inspire-$r.md" tools)" "Agent"
done

for r in $OVERSEERS; do
  tl="$(fm "$AGENTS/inspire-$r.md" tools)"
  for t in Bash Write Edit Agent; do
    hasnt "overseer: inspire-$r cannot $t" "$tl" "$t"
  done
done

# The class rule, in this file's terms: Claude Code parses every *.md here as an
# agent definition, so a stray one is a broken agent in every project.
eq "the class ships exactly five agent definitions" \
   "$(find "$AGENTS" -type f -name '*.md' | wc -l | tr -d ' ')" "5"
strays=""
for f in "$AGENTS"/*.md; do
  case "$(basename "$f")" in
    inspire-contracter.md|inspire-tester.md|inspire-implementer.md) ;;
    inspire-security-overseer.md|inspire-quality-overseer.md) ;;
    *) strays="$strays $(basename "$f")" ;;
  esac
done
eq "no .md under base/agents is anything but a shipped shell" "$strays" ""

# The roster rule is the filename convention and nothing else — no frontmatter
# key, no roster file. T10 refuses to run when either shipped overseer is gone.
eq "roster: the -overseer.md convention matches exactly the two shipped overseers" \
   "$(cd "$AGENTS" && ls -- *-overseer.md 2>/dev/null | tr '\n' ' ')" \
   "inspire-quality-overseer.md inspire-security-overseer.md "
check "roster: roles/README.md states the convention T10 enforces" \
  "grep -qF -- '-overseer.md' '$ROLES/README.md'"

for r in README $PERSONAS $OVERSEERS; do
  check "doctrine: roles/$r.md ships" "[ -f '$ROLES/$r.md' ]"
done
# T6's gate greps test sources for this token; it is fixed here, once.
check "doctrine: tester.md fixes the @claim citation token" \
  "grep -qF '@claim <claim-id>' '$ROLES/tester.md'"

# The refactor is a move: each relocated paragraph has exactly one home left.
for p in "Never silence the toolchain" "One test = one scenario" \
         "Semantic duplication no linter sees" "Hardcoded secrets"; do
  eq "one home: '$p' is claimed by exactly one file" \
     "$(grep -rlF "$p" "$PLUGIN_ROOT/base/skills" | wc -l | tr -d ' ')" "1"
done

# ---------------------------------------------------------------------------
# Destination side — init.
# ---------------------------------------------------------------------------
proj="$(mktemp -d)/proj"; mkdir -p "$proj"
( cd "$proj" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$proj" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
for r in $PERSONAS $OVERSEERS; do
  check "init: inspire-$r.md landed" "[ -f '$proj/.claude/agents/inspire-$r.md' ]"
  check "init: inspire-$r.md is byte-identical to what ships" \
    "cmp -s '$AGENTS/inspire-$r.md' '$proj/.claude/agents/inspire-$r.md'"
  check "init: the role doc it names resolves in the project" \
    "[ -f '$proj/$DEPLOYED_ROLES/$r.md' ]"
done
check "init: roles/README.md resolves too" "[ -f '$proj/$DEPLOYED_ROLES/README.md' ]"
check "init: no shell came out executable" \
  "[ -z \"\$(find '$proj/.claude/agents' -type f -perm -u+x)\" ]"

# A doctrine pointer that resolves nowhere is worse than no pointer, so every
# deployed path the shells and the role docs name is checked against a real
# materialized project rather than read for plausibility.
missing=""
while IFS= read -r p; do
  [ -e "$proj/$p" ] || missing="$missing $p"
done < <(grep -rhoE '\.claude/(skills|agents)/[A-Za-z0-9_./-]+' "$AGENTS" "$ROLES" \
         | sed 's/[.,)]*$//' | LC_ALL=C sort -u)
eq "init: every deployed path the shells and role docs cite resolves" "$missing" ""
# The derived contract is T4's file; both roles cite it by path, and the citation
# is verified when the two branches meet.
if [ -f "$PLUGIN_ROOT/base/skills/_references/derived-contract.md" ]; then
  check "init: the derived-contract reference the roles cite resolves" \
    "[ -f '$proj/.claude/skills/_references/derived-contract.md' ]"
else
  skipped 1 "derived-contract.md is T4's; the citation is verified at merge"
fi

# ---------------------------------------------------------------------------
# Destination side — update onto a released fixture. The class postdates every
# shipped manifest, so each shell must arrive as a creation, and an operator's
# own agent file beside them must survive by construction.
# ---------------------------------------------------------------------------
FIXTURE_WORK="$(mktemp -d)"
# The tag is spelled out: run.sh greps these call sites for what to pre-build.
FIXTURE_BASE="$(fixture_from_tag v0.6.0 "$FIXTURE_WORK" "$REPO")"
check "fixture: the v0.6.0 baseline built" \
  "[ -n '$FIXTURE_BASE' ] && [ -f '$FIXTURE_BASE/.inspire.lock' ]"
up="$(mktemp -d)/proj"; mkdir -p "$up"
# Guarded, because an unbuilt fixture leaves the path empty and "$EMPTY/." is /.
[ -n "$FIXTURE_BASE" ] && cp -R "$FIXTURE_BASE/." "$up/"
premise "the copy is a real installed project" "[ -f '$up/.inspire.lock' ]"
premise "the released baseline ships no agent shells" \
  "[ ! -e '$up/.claude/agents' ]"
mkdir -p "$up/.claude/agents"
printf 'MY AGENT\n' > "$up/.claude/agents/mine.md"
uprep="$(mktemp)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$up" \
  >/dev/null 2>"$uprep"
for r in $PERSONAS $OVERSEERS; do
  check "update: the report calls inspire-$r.md a creation" \
    "grep -q 'create .*\.claude/agents/inspire-$r\.md' '$uprep'"
  check "update: inspire-$r.md arrived byte-identical" \
    "cmp -s '$AGENTS/inspire-$r.md' '$up/.claude/agents/inspire-$r.md'"
done
check "update: the role doctrine arrived with them" \
  "[ -f '$up/$DEPLOYED_ROLES/README.md' ]"
eq "update: the operator's own agent file is untouched" \
   "$(cat "$up/.claude/agents/mine.md")" "MY AGENT"

rm -f "$uprep"
rm -rf "$(dirname "$proj")" "$(dirname "$up")"
fixture_cleanup "$FIXTURE_WORK"
summary
