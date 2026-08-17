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
  SDD_SPEC_ROOT="spec/sdd" SDD_KB_ROOT="spec/kb" \
    "$script" ${fixture_args[@]+"${fixture_args[@]}"} 2>"$actual_stderr"
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

  if $pass; then
    echo "PASS $rule/$scenario"
  else
    failed=$((failed + 1))
    cat "$actual_stderr" >&2
  fi
  rm -f "$actual_stderr"
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

echo ""
echo "Total: $total · Failed: $failed"
[ $failed -eq 0 ]
