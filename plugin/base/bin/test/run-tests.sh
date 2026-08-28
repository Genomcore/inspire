#!/usr/bin/env bash
# plugin/base/bin/test/run-tests.sh — run quality_lib rules against fixtures
#
# Usage:
#   plugin/base/bin/test/run-tests.sh                # run all tests
#   plugin/base/bin/test/run-tests.sh <rule-name>    # run tests for one rule
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
total=0
failed=0

for fixture in "$FIXTURES_DIR"/*/*/; do
  rule="$(basename "$(dirname "$fixture")")"
  scenario="$(basename "$fixture")"

  if [ -n "$filter" ] && [ "$filter" != "$rule" ]; then
    continue
  fi

  total=$((total + 1))
  expect_file="$fixture/expect.json"
  if [ ! -f "$expect_file" ]; then
    echo "SKIP $rule/$scenario (no expect.json)" >&2
    continue
  fi

  expected_exit="$(jq -r '.exit' "$expect_file")"
  # Optional argv. Read before the pushd so the expect file is found by the
  # absolute path it already has.
  fixture_args=()
  while IFS= read -r fixture_arg; do
    fixture_args+=("$fixture_arg")
  done < <(jq -r '.args[]?' "$expect_file")
  script="$BIN_DIR/${rule}.sh"
  if [ ! -x "$script" ]; then
    echo "FAIL $rule/$scenario (rule script not executable: $script)" >&2
    failed=$((failed + 1))
    continue
  fi

  pushd "$fixture" >/dev/null
  # Run per-fixture setup (e.g., mtime-controlled touch commands).
  # Uses a sub-shell so the cd inside setup.sh cannot pollute the parent state.
  if [ -f "setup.sh" ]; then
    ( cd "$fixture" && bash setup.sh ) 2>/dev/null
  fi
  actual_stderr="$(mktemp)"
  actual_stdout="$(mktemp)"
  SDD_SPEC_ROOT="spec/sdd" SDD_KB_ROOT="spec/kb" \
    "$script" ${fixture_args[@]+"${fixture_args[@]}"} >"$actual_stdout" 2>"$actual_stderr"
  actual_exit=$?
  popd >/dev/null

  pass=true
  if [ "$actual_exit" != "$expected_exit" ]; then
    pass=false
    echo "FAIL $rule/$scenario (exit: expected $expected_exit, got $actual_exit)" >&2
  fi

  while IFS= read -r exp_finding; do
    rule_match="$(echo "$exp_finding" | jq -r '.rule')"
    msg_substr="$(echo "$exp_finding" | jq -r '.message_substring')"
    sev_match="$(echo "$exp_finding" | jq -r '.severity // ""')"
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
  done < <(jq -c '.findings[]?' "$expect_file")

  # Absence assertions: each entry is a literal substring that must not appear.
  while IFS= read -r forbidden; do
    [ -z "$forbidden" ] && continue
    if grep -Fq "$forbidden" "$actual_stderr"; then
      pass=false
      echo "FAIL $rule/$scenario (forbidden output present: '$forbidden')" >&2
    fi
  done < <(jq -r '.forbidden[]?' "$expect_file")

  # A tool's product is its stdout, so a fixture may pin it whole … Each side is
  # normalized separately and the normalization's own exit status is checked: a
  # comparison of two things `jq` could not read passes trivially, which is how a
  # golden regenerated from a broken run would freeze the breakage. An EMPTY file
  # is the sharp case: `jq -S .` reads one happily and prints nothing, so two
  # empty sides compare equal — a fixture that pins stdout needs stdout.
  expected_stdout="$(jq -r '.stdout // ""' "$expect_file")"
  if [ -n "$expected_stdout" ]; then
    want_norm="$(mktemp)"; got_norm="$(mktemp)"
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
    rm -f "$want_norm" "$got_norm"
  fi

  # … or state one thing about it at a time. An entry missing either key is a
  # defect in the fixture, not a pass: `jq -r '.equals'` on an entry without one
  # yields "null", and "null" is what an unreadable stdout yields too.
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
  rm -f "$actual_stderr" "$actual_stdout"
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

echo ""
echo "Total: $total · Failed: $failed"
[ $failed -eq 0 ]
