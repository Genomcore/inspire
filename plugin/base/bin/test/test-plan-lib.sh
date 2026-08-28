#!/usr/bin/env bash
# plugin/base/bin/test/test-plan-lib.sh — the assertions about `plan` that a
# fixture directory cannot make.
#
# `run-tests.sh` runs one fixture at a time and compares one run's stdout with
# one golden file or one `jq` probe, which covers every per-scope claim the
# goldens state. Four kinds of assertion do not fit that shape and live here
# instead, wired in by hand exactly as `test-derive-lib.sh` is:
#
#   ACROSS TWO RUNS — that two plans over one tree are byte-identical. A golden
#   pins one run against a file; determinism is a claim about the RELATIONSHIP
#   between two runs, and no single fixture holds it.
#
#   ABOUT THE TREE, NOT THE OUTPUT — that a run wrote nothing. The harness only
#   ever looks at stdout, stderr and the exit code, so "the fixture is exactly as
#   it was" is invisible to it.
#
#   ACROSS THE CODE AND THE DOCUMENT — that the `PR-*` ids the script can emit
#   and the ids `_references/emanation-plan.md` catalogues are the same set. The
#   doc stays the authority a human reads; this is what keeps the two from
#   drifting.
#
#   AGAINST A BROKEN BIN TREE — the overseer shape's other four writing tools,
#   and the exit-6 path a working `derive` never reaches. A fixture cannot state
#   either: the harness runs the real scripts.
#
# Usage: bash plugin/base/bin/test/test-plan-lib.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
BIN="$HERE/.."
FX="$HERE/fixtures/emanate-plan"
SKILLS="$BIN/../skills"
DOC="$SKILLS/_references/emanation-plan.md"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
ne(){ if [ "$2" != "$3" ]; then ok "$1"; else bad "$1 (both are '$2')"; fi; }

TMP="$(mktemp -d -t inspire-plan-lib.XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# plan_in <fixture> <arg>… — one plan, run the way the harness runs it.
plan_in() {
  local fx="$1"; shift
  ( cd "$FX/$fx" && SDD_SPEC_ROOT=spec/sdd SDD_KB_ROOT=spec/kb \
      bash "$BIN/emanate-plan.sh" --profiles-root spec/profiles \
        --agents-root spec/agents "$@" 2>/dev/null )
}

# ─────────────────────────────────────────────────────────────────────────────
# Two runs over one tree are byte-identical
# ─────────────────────────────────────────────────────────────────────────────

first="$(plan_in clean-three-waves)"
second="$(plan_in clean-three-waves)"
eq "two plans over one tree are byte-identical" "$first" "$second"
ne "and the plan is not empty" "$first" ""

# ─────────────────────────────────────────────────────────────────────────────
# The run wrote nothing. Content AND mtime: a rewrite with identical bytes is
# still a write, and the whole `--mode plan` ethos is that there is not one.
# ─────────────────────────────────────────────────────────────────────────────

tree_state() {
  find "$1" -type f | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s %s\n' "$f" "$(cksum < "$f")"
  done
}

before="$(tree_state "$FX/clean-three-waves")"
marker="$TMP/marker"; : > "$marker"
plan_in clean-three-waves >/dev/null
after="$(tree_state "$FX/clean-three-waves")"
eq "a plan run leaves every byte of the scanned tree alone" "$before" "$after"
eq "and touches no file's mtime either" \
  "$(find "$FX/clean-three-waves" -type f -newer "$marker" | LC_ALL=C grep -c .)" "0"

# A refusal writes nothing either — it takes a different path out of the script.
before="$(tree_state "$FX/pr-11-cycle")"
: > "$marker"
plan_in pr-11-cycle >/dev/null
eq "a refused run leaves the tree alone too" "$before" "$(tree_state "$FX/pr-11-cycle")"
eq "and touches no mtime on that path either" \
  "$(find "$FX/pr-11-cycle" -type f -newer "$marker" | LC_ALL=C grep -c .)" "0"

# ─────────────────────────────────────────────────────────────────────────────
# The catalogue in the code equals the catalogue in the document
# ─────────────────────────────────────────────────────────────────────────────

if [ ! -f "$DOC" ]; then
  bad "emanation-plan.md is where the scripts say it is"
else
  code_ids="$(LC_ALL=C grep -hoE 'plan_(find|refuse) "PR-[0-9]+"' "$BIN"/lib/plan-*.sh \
              | LC_ALL=C grep -oE 'PR-[0-9]+' | LC_ALL=C sort -u | tr '\n' ' ')"
  doc_ids="$(awk '/^\| `PR-[0-9]+`/ { print }' "$DOC" \
             | LC_ALL=C grep -oE 'PR-[0-9]+' | LC_ALL=C sort -u | tr '\n' ' ')"
  eq "every PR-* the code emits is catalogued, and every catalogued id is emitted" \
    "$code_ids" "$doc_ids"
  ne "and the catalogue is not empty" "$code_ids" " "
fi

# ─────────────────────────────────────────────────────────────────────────────
# The overseer shape: every writing tool refuses, and a shell with no `tools:`
# line refuses as well. One fixture pins `Bash`; the rule binds five tools and a
# missing line, and each needs its own agents root.
# ─────────────────────────────────────────────────────────────────────────────

# overseer_verdict <frontmatter-tools-line> — exit code and refusal classes from
# a run whose agents root carries one extra `*-overseer.md` shaped that way.
overseer_verdict() {
  local line="$1" root="$TMP/agents.$RANDOM" out code
  mkdir -p "$root"
  cp "$FX/clean-single-unit/spec/agents"/*.md "$root/"
  {
    printf -- '---\nname: extra-overseer\ndescription: "a project lens"\n'
    [ -n "$line" ] && printf '%s\n' "$line"
    printf -- 'model: inherit\n---\n\nA project-added lens.\n'
  } > "$root/extra-overseer.md"
  out="$( cd "$FX/clean-single-unit" && SDD_SPEC_ROOT=spec/sdd SDD_KB_ROOT=spec/kb \
          bash "$BIN/emanate-plan.sh" --profiles-root spec/profiles \
            --agents-root "$root" 2>/dev/null )"
  code=$?
  printf '%s\t%s' "$code" \
    "$(printf '%s' "$out" | jq -r '[.refused[]?.code] | unique | join(",")' 2>/dev/null)"
}

for tool in Bash Write Edit NotebookEdit Agent; do
  eq "an overseer whose tools: line names $tool refuses the whole run" \
    "$(overseer_verdict "tools: Read, Grep, $tool")" "$(printf '4\tPR-10')"
done
eq "an overseer with no tools: line at all refuses — it inherits every tool" \
  "$(overseer_verdict "")" "$(printf '4\tPR-10')"
eq "and a read-only project overseer is simply added to the roster" \
  "$(overseer_verdict "tools: Read, Grep, Glob")" "$(printf '0\t')"

# ─────────────────────────────────────────────────────────────────────────────
# Exit 6 — the defensive path. Documented, and reachable only from a `derive`
# that misbehaves, which the real one does not.
# ─────────────────────────────────────────────────────────────────────────────

STUB="$TMP/bin"
mkdir -p "$STUB/lib"
cp "$BIN"/*.sh "$STUB/" && cp "$BIN"/lib/*.sh "$STUB/lib/"
printf '#!/usr/bin/env bash\nexit 3\n' > "$STUB/emanate-derive.sh"
chmod +x "$STUB/emanate-derive.sh"
stub_out="$( cd "$FX/clean-single-unit" && SDD_SPEC_ROOT=spec/sdd SDD_KB_ROOT=spec/kb \
             bash "$STUB/emanate-plan.sh" --profiles-root spec/profiles \
               --agents-root spec/agents 2>/dev/null )"
eq "a derive exiting outside {0,4} is exit 6" "$?" "6"
eq "and exit 6 prints nothing on stdout" "$stub_out" ""

# ─────────────────────────────────────────────────────────────────────────────
# Two --scope flags union rather than intersect
# ─────────────────────────────────────────────────────────────────────────────

both="$(plan_in clean-three-waves --scope spec/sdd/auth --scope spec/sdd/audit \
        | jq -r '[.units[].id] | join(",")')"
eq "two scopes name one vault, not two disjoint checks" \
  "$both" "audit.event,auth.org,auth.user,auth.user.list"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
