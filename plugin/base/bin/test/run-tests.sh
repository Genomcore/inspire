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
#                     "forbidden": ["substring", ...]
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
#   C finding_count · B forbidden substring
#   T a value this protocol cannot carry
#
# — and the reader below turns them back into the same variables the assertions
# always used.
#
# `T` is the protocol's own guard, and it is not hypothetical: the delimiters
# are tab and newline, so a value containing either would be read as two fields
# or two records and would then assert something other than what the fixture
# says. Nothing this reader handles has ever carried either delimiter; a fixture
# that starts to fails loudly instead.
EXPECT_READER='
  def vals: [ .args[]?, (.findings[]? | .rule, .message_substring, (.severity // "")),
              .forbidden[]? ]
            | map(tostring);
  [ (if (vals | any(test("[\t\n]"))) then ["T"] else [] end),
    ["E\t" + (.exit | tostring)],
    (.args // [] | map("A\t" + .)),
    (.findings // [] | map("F\t" + (.severity // "") + "\t" + (.rule // "")
                              + "\t" + (.message_substring // ""))),
    (if has("finding_count") then ["C\t" + (.finding_count | tostring)] else [] end),
    (.forbidden // [] | map("B\t" + .))
  ] | flatten | .[]
'

# One scratch file for the whole sweep instead of a mktemp call per fixture.
# Truncated by the `>` redirection on every run, and private to this process, so
# any number of run-tests.sh can run side by side.
RUN_TMP="$(mktemp -d)"
trap 'rm -rf "$RUN_TMP"' EXIT
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
  expected_exit=""; expected_count=""; undelimitable=0
  fixture_args=(); exp_findings=(); exp_forbidden=()
  while IFS= read -r rec; do
    case "$rec" in
      T)   undelimitable=1 ;;
      E*)  expected_exit="${rec#E$TAB}" ;;
      A*)  fixture_args+=("${rec#A$TAB}") ;;
      F*)  exp_findings+=("${rec#F$TAB}") ;;
      C*)  expected_count="${rec#C$TAB}" ;;
      B*)  exp_forbidden+=("${rec#B$TAB}") ;;
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
    "$script" ${fixture_args[@]+"${fixture_args[@]}"} >/dev/null 2>"$actual_stderr"
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

if [ -z "$filter" ]; then
  total=$((total + 1))
  split_out="$(mktemp)"
  if bash "$SCRIPT_DIR/test-adr-split.sh" >"$split_out" 2>&1; then
    echo "PASS adr-split.sh/behaviour"
  else
    failed=$((failed + 1))
    echo "FAIL adr-split.sh/behaviour" >&2
    cat "$split_out" >&2
  fi
  rm -f "$split_out"
fi

echo ""
echo "Total: $total · Failed: $failed"
[ $failed -eq 0 ]
