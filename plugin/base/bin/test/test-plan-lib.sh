#!/usr/bin/env bash
# plugin/base/bin/test/test-plan-lib.sh — the assertions about `plan` that a
# fixture directory cannot make.
#
# `run-tests.sh` runs one fixture at a time and compares one run's stdout with
# one golden file or one `jq` probe, which covers every per-scope claim the
# goldens state. Six kinds of assertion do not fit that shape and live here
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
#   AGAINST THE SHIPPED PROFILES — that every framework profile INSPIRE installs
#   satisfies the resolver. A fixture carries its own `spec/profiles` tree, so no
#   golden can say anything about the profiles a real project gets, and `PR-06`
#   is per framework: one missing `language:` line refuses a whole stack's units.
#
#   AGAINST A BROKEN BIN TREE — the overseer shape's other four writing tools,
#   and the exit-6 path a working `derive` never reaches. A fixture cannot state
#   either: the harness runs the real scripts.
#
#   POSITIVELY ABOUT STDERR — WHICH diagnosis a rejected selector printed. A
#   fixture's `forbidden` can only say a substring is absent, and "the operator
#   can tell a typo from a wrong-way segment" is a claim about what the message
#   does say.
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

# Realization, the selectors and the goal each add a list to stdout, so each is a
# new way for a plan to reorder itself between runs.
first="$(plan_in realized-shrinks-waves --tests-root tests)"
second="$(plan_in realized-shrinks-waves --tests-root tests)"
eq "two plans that computed realization are byte-identical too" "$first" "$second"
first="$(plan_in canonical-example --reemanate 'auth.user..' --goal users.detail)"
second="$(plan_in canonical-example --reemanate 'auth.user..' --goal users.detail)"
eq "and so are two plans carrying a selection and a goal" "$first" "$second"
ne "and that plan is not empty either" "$first" ""

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

# The tests roots are a new tree a run reads, and reading is all it may do: a
# `--tests-root` is somebody's source directory, not a scratch space.
before="$(tree_state "$FX/realized-shrinks-waves")"
: > "$marker"
plan_in realized-shrinks-waves --tests-root tests >/dev/null
eq "a run that walked a --tests-root leaves that tree alone" \
  "$before" "$(tree_state "$FX/realized-shrinks-waves")"
eq "and touches no mtime under it either" \
  "$(find "$FX/realized-shrinks-waves" -type f -newer "$marker" | LC_ALL=C grep -c .)" "0"

# ─────────────────────────────────────────────────────────────────────────────
# The catalogue in the code equals the catalogue in the document
# ─────────────────────────────────────────────────────────────────────────────

if [ ! -f "$DOC" ]; then
  bad "emanation-plan.md is where the scripts say it is"
else
  code_ids="$(LC_ALL=C grep -hoE 'plan_(find|refuse) "PR-[0-9]+"' \
                "$BIN"/lib/plan-*.sh "$BIN"/emanate-plan.sh \
              | LC_ALL=C grep -oE 'PR-[0-9]+' | LC_ALL=C sort -u | tr '\n' ' ')"
  doc_ids="$(awk '/^\| `PR-[0-9]+`/ { print }' "$DOC" \
             | LC_ALL=C grep -oE 'PR-[0-9]+' | LC_ALL=C sort -u | tr '\n' ' ')"
  eq "every PR-* the code emits is catalogued, and every catalogued id is emitted" \
    "$code_ids" "$doc_ids"
  ne "and the catalogue is not empty" "$code_ids" " "
fi

# ─────────────────────────────────────────────────────────────────────────────
# The SHIPPED profiles satisfy the resolver they are read by. A fixture carries
# its own `spec/profiles` tree, so no golden can state anything about the
# profiles a real project installs — and `PR-06` is per framework now, which
# makes every shipped framework profile's `language:` line load-bearing.
# ─────────────────────────────────────────────────────────────────────────────

PROFILES="$SKILLS/inspire-code/profiles"
. "$BIN/_lib.sh"

# profile_language <id> — that profile's `language:` value, or empty.
profile_language() { sdd_fm_value "$PROFILES/$1.md" '.language'; }

if [ ! -d "$PROFILES" ]; then
  bad "the shipped profiles directory is where the resolver's default says it is"
else
  broken=""
  for p in "$PROFILES"/*.md; do
    case "$(basename "$p")" in README.md|_*) continue ;; esac
    [ "$(sdd_fm_value "$p" '.layer')" = "language" ] && continue
    lang="$(sdd_fm_value "$p" '.language')"
    [ -n "$lang" ] || continue
    [ -f "$PROFILES/$lang.md" ] \
      && [ "$(sdd_fm_value "$PROFILES/$lang.md" '.layer')" = "language" ] \
      && continue
    broken="$broken $(basename "$p" .md)->$lang"
  done
  eq "every shipped framework profile that names a language resolves one" "$broken" ""
  # R2: angular closes with one line, and the two native stacks refuse on
  # purpose — no `swift` or `kotlin` profile ships, and inventing a thin one
  # would put the loop's least-checked doctrine on its least-checked stacks.
  eq "angular names the typescript language profile" "$(profile_language angular)" "typescript"
  eq "react names it too" "$(profile_language react)" "typescript"
  eq "nestjs names it too" "$(profile_language nestjs)" "typescript"
  eq "ios deliberately names none" "$(profile_language ios)" ""
  eq "and android deliberately names none" "$(profile_language android)" ""
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
# Exit 2 — the usage answers a fixture cannot state, because `run-tests.sh`
# gives every fixture one argv and these are eight different ones. Each has to
# print NOTHING on stdout as well: exit 2 carries no verdict, and a consumer
# reading a half-plan off a rejected invocation is the failure mode.
# ─────────────────────────────────────────────────────────────────────────────

# usage_run <fixture> <arg>… — the exit code and whether stdout was empty.
usage_run() {
  local fx="$1" out code; shift
  out="$(plan_in "$fx" "$@")"
  code=$?
  printf '%s\t%s' "$code" "$([ -z "$out" ] && echo empty || echo "SOMETHING")"
}

eq "an empty --reemanate selector is a usage error" \
  "$(usage_run clean-three-waves --reemanate '')" "$(printf '2\tempty')"
eq "a selector with no left-hand node is a usage error" \
  "$(usage_run clean-three-waves --reemanate '..auth.org')" "$(printf '2\tempty')"
eq "a selector naming two segments is a usage error" \
  "$(usage_run clean-three-waves --reemanate 'a..b..c')" "$(printf '2\tempty')"
eq "a --goal selector that names no frontier unit is a usage error" \
  "$(usage_run clean-three-waves --goal 'billing.*')" "$(printf '2\tempty')"
eq "a --reemanate selector that names no frontier unit is a usage error" \
  "$(usage_run clean-three-waves --reemanate 'billing.invoice')" "$(printf '2\tempty')"
eq "a segment whose endpoints share no ordering path is a usage error" \
  "$(usage_run clean-three-waves --reemanate 'auth.user.list..auth.org')" "$(printf '2\tempty')"
eq "a second --goal is a usage error" \
  "$(usage_run clean-three-waves --goal auth.org --goal auth.user)" "$(printf '2\tempty')"
eq "a --tests-root that is not there is a usage error" \
  "$(usage_run clean-three-waves --tests-root no/such/tree)" "$(printf '2\tempty')"
# The counterpart, or every row above would pass on a tool that refused
# everything: the same flags with real arguments plan normally.
eq "and the same flags with arguments that resolve exit 0" \
  "$(usage_run canonical-example --reemanate 'users.*' --goal users.detail)" \
  "$(printf '0\tSOMETHING')"

# ─────────────────────────────────────────────────────────────────────────────
# A segment has a direction. `X..X` is the degenerate one — it has to resolve to
# X alone rather than to X's whole cone — and the reversed one has to SAY it is
# reversed: both endpoints are right there in the frontier, so the diagnosis a
# typo gets would send the operator hunting for a unit that exists.
# ─────────────────────────────────────────────────────────────────────────────

eq "the degenerate segment X..X selects exactly X" \
  "$(plan_in clean-three-waves --reemanate 'auth.user..auth.user' \
     | jq -c '.reemanate | {units}')" '{"units":["auth.user"]}'

# sel_diag <fixture> <arg>… — the exit code, whether stdout was empty, and which
# of the two selector diagnoses stderr carried.
sel_diag() {
  local fx="$1" out code diag=other; shift
  out="$( cd "$FX/$fx" && SDD_SPEC_ROOT=spec/sdd SDD_KB_ROOT=spec/kb \
            bash "$BIN/emanate-plan.sh" --profiles-root spec/profiles \
              --agents-root spec/agents "$@" 2>"$TMP/sel.err" )"
  code=$?
  case "$(cat "$TMP/sel.err")" in
    *"names both endpoints"*)          diag=wrong-way ;;
    *"names no unit in the frontier"*) diag=no-such-unit ;;
  esac
  printf '%s\t%s\t%s' "$code" "$([ -z "$out" ] && echo empty || echo SOMETHING)" "$diag"
}

eq "a reversed segment is diagnosed as a direction, not as a missing unit" \
  "$(sel_diag clean-three-waves --reemanate 'auth.user.list..auth.org')" \
  "$(printf '2\tempty\twrong-way')"

# ─────────────────────────────────────────────────────────────────────────────
# One grammar, two readings — the claim that no single fixture can hold, since a
# fixture directory belongs to exactly one tool. Gate covers a claim off the id
# half of the token; plan realizes a unit only when the fingerprint half matches.
# ─────────────────────────────────────────────────────────────────────────────

realized_ids() {
  plan_in "$1" --tests-root tests | jq -r '[.realized[]] | join(",")' 2>/dev/null
}
eq "a fingerprinted citation of every claim realizes the unit" \
  "$(realized_ids realized-all)" "auth.org"
eq "an id-only citation of every claim realizes nothing" \
  "$(realized_ids realized-id-only-citation)" ""
eq "and one stale fingerprint is enough to un-realize it" \
  "$(realized_ids realized-fingerprint-mismatch)" ""
gate_covered() {
  ( cd "$FX/../emanate-gate/$1" \
    && bash "$BIN/emanate-gate.sh" --contract contract.json --tests-root tests \
         --results results.json 2>/dev/null \
       | jq -r '[.claims[].status] | unique | join(",")' )
}
eq "while gate covers the claim off the id half, stale fingerprint and all" \
  "$(gate_covered token-with-fingerprint)" "covered"

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
