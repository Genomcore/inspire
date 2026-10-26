#!/usr/bin/env bash
# The five agent shells: their envelopes on the source side and their arrival on
# the destination side.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

AGENTS="$PLUGIN_ROOT/base/agents"
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
# Source side — identity and envelope.
#
# The envelope's tool half lives in this frontmatter and nowhere else: there is
# no path-level write restriction in an agent definition, so an overseer is made
# read-only by what its allowlist omits. Bash is on that list because Bash can
# write, which is the whole reason D3's "writes nothing" needs an allowlist.
# ---------------------------------------------------------------------------
premise "the plugin ships an agents payload class" "[ -d '$AGENTS' ]"

for r in $PERSONAS $OVERSEERS; do
  f="$AGENTS/inspire-$r.md"
  check "shell: inspire-$r.md ships" "[ -f '$f' ]"
  [ -f "$f" ] || continue
  nm="$(fm "$f" name)"; ds="$(fm "$f" description)"; tl="$(fm "$f" tools)"
  eq    "shell: inspire-$r declares a name equal to its stem" "$nm" "inspire-$r"
  check "shell: inspire-$r declares a non-empty description"  '[ -n "$ds" ]'
  check "shell: inspire-$r declares a tools allowlist"        '[ -n "$tl" ]'
done

for r in $PERSONAS; do
  tl="$(fm "$AGENTS/inspire-$r.md" tools)"
  has "persona: inspire-$r keeps the Agent tool (D1 self-spawn)" "$tl" "Agent"
  # Plain `Agent`, never `Agent(name)`: the docs restrict that allowlist form to a
  # main-thread agent and ignore the names inside a subagent definition, so writing
  # one here would claim an enforcement the substrate does not perform.
  hasnt "persona: inspire-$r spells Agent without a type list" "$tl" "Agent("
done

for r in $OVERSEERS; do
  tl="$(fm "$AGENTS/inspire-$r.md" tools)"
  for t in Bash Write Edit NotebookEdit Agent; do
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
done
check "init: no shell came out executable" \
  "[ -z \"\$(find '$proj/.claude/agents' -type f -perm -u+x)\" ]"

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
eq "update: the operator's own agent file is untouched" \
   "$(cat "$up/.claude/agents/mine.md")" "MY AGENT"

rm -f "$uprep"
rm -rf "$(dirname "$proj")" "$(dirname "$up")"
fixture_cleanup "$FIXTURE_WORK"
summary
