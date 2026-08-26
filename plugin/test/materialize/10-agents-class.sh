#!/usr/bin/env bash
# update reaches the agents payload class — and touches nothing else in it.
# Moved from test-materialize.sh:870-911.
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
# UPDATE reaches the agents payload class — and touches nothing else in it.
#
# The class is new at 0.8, so no shipped manifest lists a path under
# .claude/agents/. That makes an upgrade the interesting direction: the class
# arrives through the TARGET map, an operator's own file there must survive by
# construction, and an edited copy of ours must never be clobbered on a re-run.
# ---------------------------------------------------------------------------
agp="$(mktemp -d)/proj"
fixture_copy "$agp"
check "premise: the released baseline has no .claude/agents (the class postdates it)" \
  "[ ! -e '$agp/.claude/agents' ]"
mkdir -p "$agp/.claude/agents"
printf 'MY AGENT\n' > "$agp/.claude/agents/mine.md"
agrep="$(mktemp)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$agp" >/dev/null 2>"$agrep"
rc_ag=$?
check "agents: update with an operator's agents dir exits 0" "[ '$rc_ag' = 0 ]"
check "agents: the class landed"        "[ -f '$agp/.claude/agents/README.txt' ]"
check "agents: byte-identical to what ships" \
  "cmp -s '$PLUGIN_ROOT/base/agents/README.txt' '$agp/.claude/agents/README.txt'"
eq "agents: the operator's own agent file is untouched" \
   "$(cat "$agp/.claude/agents/mine.md")" "MY AGENT"
check "agents: the report announces the class as a creation" \
  "grep -q 'create .*\.claude/agents/README\.txt' '$agrep'"
check "agents: the report calls the operator's file theirs to keep" \
  "grep -q 'keep .*\.claude/agents/mine\.md' '$agrep'"
check "agents: nothing under .claude/agents came out executable" \
  "[ -z \"\$(find '$agp/.claude/agents' -type f -perm -u+x)\" ]"
check "agents: the lock is still provenance-only after the class arrived" \
  "[ \"\$(jq -r 'keys|join(\",\")' '$agp/.inspire.lock')\" = 'inspire_version,installed_at,released,template_sha' ]"

# An edited copy of a file we ship survives the NEXT update, exactly as an
# edited skill does — nobody has to resolve anything for that to hold.
printf 'MY EDIT\n' >> "$agp/.claude/agents/README.txt"
ag_h="$(shasum -a 256 "$agp/.claude/agents/README.txt" | cut -d' ' -f1)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$agp" >/dev/null 2>&1
eq "agents: a re-run does not clobber an edited agent file" \
   "$(shasum -a 256 "$agp/.claude/agents/README.txt" | cut -d' ' -f1)" "$ag_h"
eq "agents: nor their own file beside it" \
   "$(cat "$agp/.claude/agents/mine.md")" "MY AGENT"
rm -f "$agrep"; rm -rf "$(dirname "$agp")"
fixture_cleanup "$FIXTURE_WORK"
summary
