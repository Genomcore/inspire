#!/usr/bin/env bash
# plugin/base/bin/test/run-tests.sh — run quality_lib rules against fixtures
#
# Usage:
#   plugin/base/bin/test/run-tests.sh                     # run all tests
#   plugin/base/bin/test/run-tests.sh <rule>              # one rule, every scenario
#   plugin/base/bin/test/run-tests.sh <rule> <scenario>…  # named scenarios only
#
# The third form exists so one rule's fixtures can be split across processes:
# a rule with 80 fixtures is otherwise a single-core job however many cores the
# machine has, and it is the estate's longest. plugin/test/run.sh shards the
# big ones that way. The PASS/FAIL lines are per scenario either way, so the
# run's inventory does not depend on how the work was divided.
#
# Each fixture lives at plugin/base/bin/test/fixtures/{rule}/{scenario}/
# and contains:
#   - spec/sdd/...  the domain tree to scan (exported as SDD_SPEC_ROOT)
#   - spec/kb/...   the KB tree to scan, for the KB-wide rules that check
#                   features / ADRs / screens (exported as SDD_KB_ROOT)
#   - expect.json   {
#                     "exit": N,
#                     "args":      ["scope", ...],
#                     "findings":  [{rule, message_substring, severity?}, ...],
#                     "forbidden": ["substring", ...],
#                     "stdout":    "<file>",
#                     "stdout_jq": [{expr, equals}, ...]
#                   }
#
# `args` is optional and defaults to none — the same argv-free invocation every
# fixture used before it existed. It is the scope argument `review.sh` forwards
# to every rule, and it exists so the scope contract (a rule checks `$1 ∩ its
# own layers`, and nothing else) is testable rather than merely asserted.
#
# `severity` is optional; when given, the finding must carry that severity —
# this is what makes a severity claim testable rather than merely asserted.
# `forbidden` lists substrings that must NOT appear in the captured stderr. It
# exists because a fixture expecting nothing passes vacuously otherwise: exit 0
# plus an empty `findings` list matches any output at all, including the wrong
# findings. Any fixture whose point is that something does *not* fire states so
# in `forbidden`.
#
# `stdout` and `stdout_jq` are both optional and both exist for the same reason:
# a rule's product is its findings, but a TOOL's product is its stdout, and a
# fixture that asserted only the exit code of a tool would assert almost
# nothing. `stdout` names a file in the fixture directory compared with the run's
# stdout after `jq -S .` on both sides — key order is not a claim. `stdout_jq`
# asserts one `jq -r` expression at a time, which is how a fixture states a
# thing about the output without pinning the whole of it (a refusal's class set;
# that a key is absent). Every existing fixture omits both and is unaffected.
#
# Exit 0 if all tests pass, 1 otherwise.

set -uo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
BIN_DIR="$SCRIPT_DIR/.."

filter="${1:-}"
[ $# -gt 0 ] && shift
# Any remaining words name individual scenarios of that rule, which is what
# lets a caller split one rule's fixtures across processes. Nothing is required
# to pass them: no words means every scenario the rule has, exactly as before.
scenarios=("$@")
total=0
failed=0

TAB="$(printf '\t')"

# One `jq` per expect.json, not one per key and three more per expected finding:
# a 400-fixture sweep spent more time forking jq than running the rules. The
# keys come back as tagged, tab-delimited records, one per line —
#
#   E exit · A argv word · F severity,rule,message_substring
#   C finding_count · B forbidden substring · S golden stdout file
#   T a value this protocol cannot carry
#
# — and the reader below turns them back into the same variables the assertions
# always used.
#
# `T` is the protocol's own guard, and it is not hypothetical: the delimiters
# are tab and newline, so a value containing either would be read as two fields
# or two records and would then assert something other than what the fixture
# says. `stdout_jq` is READ SEPARATELY BELOW for exactly that reason — its
# `equals` is the one value in the estate that legitimately spans lines (a
# pretty-printed JSON array), and folding it in here truncated it at the first
# newline and compared against "[". Nothing this reader handles has ever
# carried either delimiter; a fixture that starts to fails loudly instead.
EXPECT_READER='
  def vals: [ .args[]?, (.findings[]? | .rule, .message_substring, (.severity // "")),
              .forbidden[]?, (.stdout // "") ]
            | map(tostring);
  [ (if (vals | any(test("[\t\n]"))) then ["T"] else [] end),
    ["E\t" + (.exit | tostring)],
    (.args // [] | map("A\t" + .)),
    (.findings // [] | map("F\t" + (.severity // "") + "\t" + (.rule // "")
                              + "\t" + (.message_substring // ""))),
    (if has("finding_count") then ["C\t" + (.finding_count | tostring)] else [] end),
    (.forbidden // [] | map("B\t" + .)),
    (if (.stdout // "") != "" then ["S\t" + .stdout] else [] end)
  ] | flatten | .[]
'

# Two scratch files for the whole sweep instead of two mktemp calls per fixture.
# Truncated by the `>` redirection on every run, and private to this process, so
# any number of run-tests.sh can run side by side.
RUN_TMP="$(mktemp -d)"
trap 'rm -rf "$RUN_TMP"' EXIT
actual_stdout="$RUN_TMP/stdout"
actual_stderr="$RUN_TMP/stderr"

# A filter narrows the GLOB, not each iteration. Walking all 400-odd fixture
# directories to skip all but one rule's cost three processes apiece — and
# run.sh calls this script once per rule, so naming the directory it wants is
# the difference between 400 iterations and a dozen. nullglob is set, so a
# filter naming no fixture directory yields no fixtures, which is what filtering
# every one of them out did before.
if [ -n "$filter" ] && [ ${#scenarios[@]} -gt 0 ]; then
  # Named scenarios. A name that resolves to nothing is a FAILURE, not a skip:
  # the caller built it from a glob over this very directory, so a miss means
  # the tree moved under it — and a shard that quietly ran nothing is the
  # vacuity class again.
  miss=0
  for s in "${scenarios[@]}"; do
    [ -d "$FIXTURES_DIR/$filter/$s" ] && continue
    echo "FAIL $filter/$s (no such fixture directory)" >&2
    miss=$((miss + 1))
  done
  set --
  for s in ${scenarios[@]+"${scenarios[@]}"}; do
    [ -d "$FIXTURES_DIR/$filter/$s" ] && set -- ${1+"$@"} "$FIXTURES_DIR/$filter/$s/"
  done
  total=$((total + miss)); failed=$((failed + miss))
elif [ -n "$filter" ]; then
  set -- "$FIXTURES_DIR/$filter"/*/
else
  set -- "$FIXTURES_DIR"/*/*/
fi

for fixture in ${1+"$@"}; do
  # .../fixtures/<rule>/<scenario>/ — split with parameter expansion, since
  # basename and dirname are two forks each and this runs per fixture.
  scenario="${fixture%/}"; rule="${scenario%/*}"
  scenario="${scenario##*/}"; rule="${rule##*/}"

  total=$((total + 1))
  expect_file="$fixture/expect.json"
  if [ ! -f "$expect_file" ]; then
    echo "SKIP $rule/$scenario (no expect.json)" >&2
    continue
  fi

  # Read before the pushd so the expect file is found by the absolute path it
  # already has. `args` is optional and defaults to none.
  expected_exit=""; expected_count=""; expected_stdout=""; undelimitable=0
  fixture_args=(); exp_findings=(); exp_forbidden=()
  while IFS= read -r rec; do
    case "$rec" in
      T)   undelimitable=1 ;;
      E*)  expected_exit="${rec#E$TAB}" ;;
      A*)  fixture_args+=("${rec#A$TAB}") ;;
      F*)  exp_findings+=("${rec#F$TAB}") ;;
      C*)  expected_count="${rec#C$TAB}" ;;
      B*)  exp_forbidden+=("${rec#B$TAB}") ;;
      S*)  expected_stdout="${rec#S$TAB}" ;;
    esac
  done < <(jq -r "$EXPECT_READER" "$expect_file")

  if [ "$undelimitable" = 1 ]; then
    echo "FAIL $rule/$scenario (expect.json value holds a tab or newline — unreadable)" >&2
    failed=$((failed + 1))
    continue
  fi

  script="$BIN_DIR/${rule}.sh"
  if [ ! -x "$script" ]; then
    echo "FAIL $rule/$scenario (rule script not executable: $script)" >&2
    failed=$((failed + 1))
    continue
  fi

  pushd "$fixture" >/dev/null
  SDD_SPEC_ROOT="spec/sdd" SDD_KB_ROOT="spec/kb" \
    "$script" ${fixture_args[@]+"${fixture_args[@]}"} >"$actual_stdout" 2>"$actual_stderr"
  actual_exit=$?
  popd >/dev/null

  pass=true
  if [ "$actual_exit" != "$expected_exit" ]; then
    pass=false
    echo "FAIL $rule/$scenario (exit: expected $expected_exit, got $actual_exit)" >&2
  fi

  for exp_finding in ${exp_findings[@]+"${exp_findings[@]}"}; do
    sev_match="${exp_finding%%$TAB*}"
    exp_finding="${exp_finding#*$TAB}"
    rule_match="${exp_finding%%$TAB*}"
    msg_substr="${exp_finding#*$TAB}"
    # sdd_finding emits severity before rule (_lib.sh), so a severity claim
    # anchors to the left of the rule id in the same JSON line.
    if [ -n "$sev_match" ]; then
      pattern="\"severity\":\"$sev_match\".*\"rule\":\"$rule_match\".*$msg_substr"
      label="severity=$sev_match, rule=$rule_match"
    else
      pattern="\"rule\":\"$rule_match\".*$msg_substr"
      label="rule=$rule_match"
    fi
    if ! grep -q "$pattern" "$actual_stderr"; then
      pass=false
      echo "FAIL $rule/$scenario (missing finding: $label, msg~='$msg_substr')" >&2
    fi
  done

  # Optional `finding_count`: assert HOW MANY findings the rule emitted, not just that
  # the expected ones are among them.
  #
  # Added because a substring assertion cannot catch a rule that reports the same defect
  # twice — found by a mutation drill, where breaking a de-duplication survived every
  # fixture. Deduplication, "report once per file", and "suppress the per-item findings"
  # are all behaviours whose only observable difference is a count, so a suite that cannot
  # express one cannot defend them. Absent from expect.json = not checked, so every
  # existing fixture is unaffected.
  if [ -n "$expected_count" ]; then
    # `grep -c` exits 1 when the count is zero, so `|| echo 0` appended a SECOND zero and
    # produced "0\n0" — which never equals "0", so `finding_count: 0` could not pass. Count
    # with a filter that always succeeds instead. Found by the first fixture that asserted
    # zero findings, which is the case the original form could not express.
    actual_count="$(grep -c '"rule":' "$actual_stderr" 2>/dev/null | head -1)"
    [ -n "$actual_count" ] || actual_count=0
    if [ "$actual_count" != "$expected_count" ]; then
      pass=false
      echo "FAIL $rule/$scenario (finding count: expected $expected_count, got $actual_count)" >&2
    fi
  fi

  # Absence assertions: each entry is a literal substring that must not appear.
  for forbidden in ${exp_forbidden[@]+"${exp_forbidden[@]}"}; do
    [ -z "$forbidden" ] && continue
    if grep -Fq "$forbidden" "$actual_stderr"; then
      pass=false
      echo "FAIL $rule/$scenario (forbidden output present: '$forbidden')" >&2
    fi
  done

  # A tool's product is its stdout, so a fixture may pin it whole … Each side is
  # normalized separately and the normalization's own exit status is checked: a
  # comparison of two things `jq` could not read passes trivially, which is how a
  # golden regenerated from a broken run would freeze the breakage. An EMPTY file
  # is the sharp case: `jq -S .` reads one happily and prints nothing, so two
  # empty sides compare equal — a fixture that pins stdout needs stdout.
  if [ -n "$expected_stdout" ]; then
    want_norm="$RUN_TMP/want"; got_norm="$RUN_TMP/got"
    if [ ! -f "$fixture/$expected_stdout" ]; then
      pass=false
      echo "FAIL $rule/$scenario (missing golden stdout: $expected_stdout)" >&2
    elif ! jq -S . "$fixture/$expected_stdout" > "$want_norm" 2>/dev/null \
         || [ ! -s "$want_norm" ]; then
      pass=false
      echo "FAIL $rule/$scenario (golden $expected_stdout is not readable JSON)" >&2
    elif ! jq -S . "$actual_stdout" > "$got_norm" 2>/dev/null || [ ! -s "$got_norm" ]; then
      pass=false
      echo "FAIL $rule/$scenario (stdout is not readable JSON)" >&2
    elif ! diff -u "$want_norm" "$got_norm" >/dev/null; then
      pass=false
      echo "FAIL $rule/$scenario (stdout differs from $expected_stdout)" >&2
      diff -u "$want_norm" "$got_norm" | head -40 >&2
    fi
  fi

  # … or state one thing about it at a time. An entry missing either key is a
  # defect in the fixture, not a pass: `jq -r '.equals'` on an entry without one
  # yields "null", and "null" is what an unreadable stdout yields too.
  #
  # These keep their own jq calls, unlike every other key: `equals` may be a
  # pretty-printed JSON value and so may span lines, which the tagged-record
  # reader above cannot carry. Command substitution keeps a value's interior
  # newlines, which is precisely what makes this form the right one here.
  while IFS= read -r probe; do
    [ -n "$probe" ] || continue
    if ! echo "$probe" | jq -e 'has("expr") and has("equals")' >/dev/null 2>&1; then
      pass=false
      echo "FAIL $rule/$scenario (stdout_jq entry needs both 'expr' and 'equals': $probe)" >&2
      continue
    fi
    probe_expr="$(echo "$probe" | jq -r '.expr')"
    probe_want="$(echo "$probe" | jq -r '.equals')"
    probe_got="$(jq -r "$probe_expr" "$actual_stdout" 2>/dev/null)"
    if [ "$probe_got" != "$probe_want" ]; then
      pass=false
      echo "FAIL $rule/$scenario (stdout_jq '$probe_expr': expected '$probe_want', got '$probe_got')" >&2
    fi
  done < <(jq -c '.stdout_jq[]?' "$expect_file")

  if $pass; then
    echo "PASS $rule/$scenario"
  else
    failed=$((failed + 1))
    cat "$actual_stderr" >&2
  fi
done

# _lib.sh is a library, not a rule: it emits no findings and has no fixture
# directory either. Its readers are asserted directly by lib-tests.sh, wired in
# here by hand for the same reason trust.sh is below.
if [ -z "$filter" ]; then
  total=$((total + 1))
  lib_out="$(mktemp)"
  if bash "$SCRIPT_DIR/lib-tests.sh" >"$lib_out" 2>&1; then
    echo "PASS _lib.sh/readers"
  else
    failed=$((failed + 1))
    echo "FAIL _lib.sh/readers" >&2
    cat "$lib_out" >&2
  fi
  rm -f "$lib_out"
fi

# escape-hatch-ratchet's --update mode rewrites its own config, and the fixture
# loop above is read-only by design — a fixture is a tree a rule scans, never
# one it rewrites. Its defining guarantee (a ceiling only ever moves DOWN) is
# asserted by a behavioural script instead, wired in by hand like the others.
if [ -z "$filter" ]; then
  total=$((total + 1))
  ratchet_out="$(mktemp)"
  if bash "$SCRIPT_DIR/test-ratchet-update.sh" >"$ratchet_out" 2>&1; then
    echo "PASS escape-hatch-ratchet/--update"
  else
    failed=$((failed + 1))
    echo "FAIL escape-hatch-ratchet/--update" >&2
    cat "$ratchet_out" >&2
  fi
  rm -f "$ratchet_out"
fi

# trust.sh is a tool, not a review rule: it emits no findings, so it has no
# fixtures/{rule}/{scenario}/ directory for the loop above to discover and needs
# its own test script wired in by hand. Guarded on an empty filter so that
# `run-tests.sh <rule-name>` still narrows to that one rule.
if [ -z "$filter" ]; then
  total=$((total + 1))
  trust_out="$(mktemp)"
  if bash "$SCRIPT_DIR/test-trust.sh" >"$trust_out" 2>&1; then
    echo "PASS trust.sh/behaviour"
  else
    failed=$((failed + 1))
    echo "FAIL trust.sh/behaviour" >&2
    cat "$trust_out" >&2
  fi
  rm -f "$trust_out"
fi

# emanate-harvest.sh is likewise a tool, not a review rule: it emits no
# findings and there is no inspire_kb/ tree to scan, only git state (refs,
# reflog, tree contents) that fixtures/{rule}/{scenario}/ has no vocabulary
# for. Same hand-wiring as trust.sh above.
if [ -z "$filter" ]; then
  total=$((total + 1))
  harvest_out="$(mktemp)"
  if bash "$SCRIPT_DIR/test-harvest.sh" >"$harvest_out" 2>&1; then
    echo "PASS emanate-harvest.sh/behaviour"
  else
    failed=$((failed + 1))
    echo "FAIL emanate-harvest.sh/behaviour" >&2
    cat "$harvest_out" >&2
  fi
  rm -f "$harvest_out"
fi

# emanate-derive.sh has fixtures — its product is stdout, which the loop above
# now compares — but three of its claims are about a RELATIONSHIP no single
# fixture holds: two derivations of near-identical trees, the library data
# against the document that specifies it, and a class id no rule emits a message
# for. Those live in their own script, hand-wired like the three above.
if [ -z "$filter" ]; then
  total=$((total + 1))
  derive_out="$(mktemp)"
  if bash "$SCRIPT_DIR/test-derive-lib.sh" >"$derive_out" 2>&1; then
    echo "PASS emanate-derive.sh/library"
  else
    failed=$((failed + 1))
    echo "FAIL emanate-derive.sh/library" >&2
    cat "$derive_out" >&2
  fi
  rm -f "$derive_out"
fi

# emanate-plan.sh has fixtures too, and four of its claims sit outside any one of
# them: that two runs over one tree are byte-identical, that a run leaves every
# byte and every mtime of that tree alone, that the PR-* ids the code emits are
# exactly the ids emanation-plan.md catalogues, and the shapes only a broken bin
# tree can reach. Same hand-wiring as the four above.
if [ -z "$filter" ]; then
  total=$((total + 1))
  plan_out="$(mktemp)"
  if bash "$SCRIPT_DIR/test-plan-lib.sh" >"$plan_out" 2>&1; then
    echo "PASS emanate-plan.sh/library"
  else
    failed=$((failed + 1))
    echo "FAIL emanate-plan.sh/library" >&2
    cat "$plan_out" >&2
  fi
  rm -f "$plan_out"
fi

# emanate-gate.sh has fixtures too; four of its claims fit none of them: a run
# leaves the fixture tree byte- and mtime-identical, `--contract -` and a doubled
# `--tests-root` read the verdict a plain file does, the GV-* ids the code names
# still equal the catalogue documenting them, and stdout is EMPTY on every exit
# that carries no verdict. Same hand-wiring as the five above.
if [ -z "$filter" ]; then
  total=$((total + 1))
  gate_out="$(mktemp)"
  if bash "$SCRIPT_DIR/test-gate-lib.sh" >"$gate_out" 2>&1; then
    echo "PASS emanate-gate.sh/library"
  else
    failed=$((failed + 1))
    echo "FAIL emanate-gate.sh/library" >&2
    cat "$gate_out" >&2
  fi
  rm -f "$gate_out"
fi

# emanate-results.sh has fixtures too, and its central claim fits none of them:
# that the manifest it emits is the one `lib/gate-results.sh` actually reads. A
# fixture pins its stdout against a golden written by the same hand, which two
# tools that had drifted apart would pass just as happily. The cross-tool run,
# the absolute-path stripping no portable golden can carry, and the byte-level
# emptiness of a refusal's stdout live there. Same hand-wiring as the six above.
if [ -z "$filter" ]; then
  total=$((total + 1))
  results_out="$(mktemp)"
  if bash "$SCRIPT_DIR/test-results.sh" >"$results_out" 2>&1; then
    echo "PASS emanate-results.sh/behaviour"
  else
    failed=$((failed + 1))
    echo "FAIL emanate-results.sh/behaviour" >&2
    cat "$results_out" >&2
  fi
  rm -f "$results_out"
fi

echo ""
echo "Total: $total · Failed: $failed"
[ $failed -eq 0 ]
