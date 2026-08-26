#!/usr/bin/env bash
# The agents payload class: what an earlier release must and must not emit.
# Moved from test-manifest.sh:51-100.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
GEN="$HERE/../scripts/gen-manifest.sh"
. "$HERE/lib/assert.sh"

# ---------------------------------------------------------------------------
# The agents payload class (base/agents/ → .claude/agents/).
#
# A class added at 0.8 must cost every EARLIER manifest nothing: the generator
# reads the map per class, and a release that predates the class simply has no
# tree entries under it. The nine-manifest sweep below is the load-bearing half
# of that; these are the two directed halves it cannot state — that a past tag
# emits zero agents entries, and that a revision which HAS the directory emits
# them at .claude/agents/ under the unchanged 0.3 layout id.
# ---------------------------------------------------------------------------
m70="$(mktemp)"; bash "$GEN" --tag v0.7.0 --repo "$REPO" > "$m70"
check "premise: v0.7.0 predates the class (no plugin/base/agents in its tree)" \
  "[ \"\$(git -C '$REPO' ls-tree -r --name-only v0.7.0 -- plugin/base/agents | wc -l | tr -d ' ')\" = 0 ]"
check "0.7.0 lists no .claude/agents paths" \
  "[ \"\$(jq -r '[.files|keys[]|select(startswith(\".claude/agents/\"))]|length' '$m70')\" = 0 ]"
eq "0.7.0 layout is untouched by the new class" "$(jq -r .layout "$m70")" "0.3"
rm -f "$m70"

# A synthetic revision that DOES carry the class. Built rather than borrowed:
# no tag has the directory, and the assertion is about the generator's reach,
# not about any release.
gsrc="$(mktemp -d)"
mkdir -p "$gsrc/plugin/.claude-plugin" "$gsrc/plugin/base/agents" "$gsrc/plugin/base/skills/inspire-x"
printf '{"version":"9.9.9","released":"2099-01-01"}\n' > "$gsrc/plugin/.claude-plugin/plugin.json"
printf -- '---\nname: inspire-tester\n---\nbody\n' > "$gsrc/plugin/base/agents/inspire-tester.md"
printf -- '---\nname: x\n---\nskill\n' > "$gsrc/plugin/base/skills/inspire-x/SKILL.md"
( cd "$gsrc" && git init -q && git add -A \
  && git -c user.email=f@f -c user.name=f -c commit.gpgsign=false \
         -c core.hooksPath=/dev/null commit -qm synthetic ) >/dev/null 2>&1
check "premise: the synthetic revision really carries plugin/base/agents/" \
  "[ \"\$(git -C '$gsrc' ls-tree -r --name-only HEAD -- plugin/base/agents | wc -l | tr -d ' ')\" = 1 ]"
gm="$(mktemp)"; bash "$GEN" --tag HEAD --repo "$gsrc" > "$gm" 2>/dev/null
check "a revision with base/agents/ emits the .claude/agents/ path" \
  "[ \"\$(jq -r '.files|has(\".claude/agents/inspire-tester.md\")' '$gm')\" = true ]"
eq "its hash is the blob's, not a placeholder" \
   "$(jq -r '.files[".claude/agents/inspire-tester.md"]' "$gm")" \
   "$(git -C "$gsrc" show HEAD:plugin/base/agents/inspire-tester.md | shasum -a 256 | cut -d' ' -f1)"
# THE SHIFT BUG THIS GUARDS: MAP_NAMES and MAP_DESTS are two parallel lists
# indexed by position (`cut -d' ' -f$i`). Append to one and not the other and
# every class after the insertion point silently materializes at the wrong root.
check "adding the class did not shift the other classes' destinations" \
  "[ \"\$(jq -r '.files|has(\".claude/skills/inspire-x/SKILL.md\")' '$gm')\" = true ]"
eq "a class-carrying revision still reports the 0.3 layout" "$(jq -r .layout "$gm")" "0.3"
map_arity() { grep -E "^  $1=" "$GEN" | sed -e 's/^[^"]*"//' -e 's/".*$//' | awk '{print NF}' | tr '\n' ' '; }
eq "premise: the generator still has two layout branches to check" \
   "$(grep -cE '^  MAP_NAMES=' "$GEN" | tr -d ' ')" "2"
eq "MAP_NAMES and MAP_DESTS have the same arity, branch for branch" \
   "$(map_arity MAP_NAMES)" "$(map_arity MAP_DESTS)"
eq "the 0.3 branch names four classes" "$(map_arity MAP_NAMES | cut -d' ' -f1)" "4"
rm -f "$gm"; rm -rf "$gsrc"
summary
