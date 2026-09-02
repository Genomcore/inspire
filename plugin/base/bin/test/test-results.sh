#!/usr/bin/env bash
# plugin/base/bin/test/test-results.sh — the claims about `emanate-results`
# no fixture/expect.json can hold, modelled on test-harvest.sh and
# test-gate-lib.sh:
#
#   THE MANIFEST IS THE ONE GATE READS — the claim this whole script exists
#   for. A fixture pins emanate-results.sh's stdout against a golden written
#   by the same hand; only feeding that stdout to `emanate-gate.sh --results`
#   proves the two tools agree, and it is the one failure mode that would
#   otherwise surface as every claim silently reading as not-run.
#
#   REPO-RELATIVE PATHS — jest reports ABSOLUTE file paths and gate joins
#   against repo-relative citations, so `--root` stripping is load-bearing.
#   No golden can carry an absolute path and stay portable.
#
#   WRITES NOTHING — expect.json inspects stdout and an exit code; it has no
#   vocabulary for "and the tree it read is untouched afterward".
#
#   STDOUT IS EMPTY on 2/3/5 — a fixture's `stdout_jq` probe passes on
#   unparseable output as readily as on none, so the byte-level emptiness of
#   a refusal is asserted here instead.
#
#   THE OFFENDING REPORT IS NAMED — two reports are the normal case, so
#   "which one" is the first thing an operator needs; expect.json asserts
#   only against a rule's `"rule":` JSON lines, which a tool emits none of.
#
# EVERY RUN BELOW IS CHECKED FOR HAVING RUN. A manifest diff and a stdout
# diff both pass trivially when both sides are empty, so each comparison is
# paired with an assertion that the run exited as expected and produced
# something parseable.
#
# Usage: bash plugin/base/bin/test/test-results.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
BIN="$HERE/.."
RESULTS="$BIN/emanate-results.sh"
FX="$HERE/fixtures/emanate-results"
FX_GATE="$HERE/fixtures/emanate-gate"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

sha_of() { command -v sha256sum >/dev/null 2>&1 && sha256sum "$1" || shasum -a 256 "$1"; }

# manifest <dir> — one `path hash mtime` line per file, sorted, so two runs
# over the same tree diff byte-for-byte regardless of directory read order.
manifest() {
  local dir="$1" f
  find "$dir" -type f | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s %s %s\n' "${f#"$dir"/}" "$(sha_of "$f" | awk '{print $1}')" "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")"
  done
}

WORK="$(mktemp -d -t inspire-results.XXXXXX)" || exit 1
trap 'rm -rf "$WORK"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
# The manifest is the one gate reads
#
# The gate fixture `all-covered` ships a hand-written results.json and the
# contract + tests it is joined against. A jest report describing that same
# run must produce a manifest gate reaches the IDENTICAL verdict on — not
# merely one gate tolerates.
# ─────────────────────────────────────────────────────────────────────────────

X="$WORK/xtool"; mkdir -p "$X"
cp -R "$FX_GATE/all-covered/." "$X/"

cat > "$X/jest-report.json" <<EOF
{ "success": true,
  "testResults": [
    { "name": "$X/tests/create.spec.ts",
      "status": "passed",
      "assertionResults": [
        { "ancestorTitles": [], "title": "provisions an account end to end",
          "fullName": "provisions an account end to end",
          "status": "passed", "failureMessages": [] } ] } ] }
EOF

produced="$X/produced-results.json"
( cd "$X" && bash "$RESULTS" --from jest-report.json > "$produced" 2>/dev/null )
eq "the emitter ran and produced a schema-stamped manifest" \
  "$?:$(jq -r '.schema' "$produced" 2>/dev/null)" "0:inspire.suite-results/1"

# Gate's own exit code is the claim here, so it is read from gate and not
# from a `jq` at the end of a pipeline, which is what `$?` would otherwise be.
( cd "$X" && bash "$BIN/emanate-gate.sh" \
  --contract contract.json --tests-root tests --results results.json >"$X/hand.json" 2>/dev/null )
hand_code=$?
( cd "$X" && bash "$BIN/emanate-gate.sh" \
  --contract contract.json --tests-root tests --results produced-results.json >"$X/made.json" 2>/dev/null )
made_code=$?
hand_verdict="$(jq -S . "$X/hand.json" 2>/dev/null)"
made_verdict="$(jq -S . "$X/made.json" 2>/dev/null)"

eq "gate reaches a pass verdict on the EMITTED manifest (never exit 5)" \
  "$made_code:$(printf '%s' "$made_verdict" | jq -r '.verdict' 2>/dev/null)" "0:pass"
eq "gate's hand-written control also passed, so the comparison is not two failures" \
  "$hand_code:$(printf '%s' "$hand_verdict" | jq -r '.verdict' 2>/dev/null)" "0:pass"
eq "the emitted manifest and the hand-written one yield the same verdict" \
  "$made_verdict" "$hand_verdict"

# The schema string and the status vocabulary are the two literals the two
# tools must agree on byte-for-byte; each is read from the OTHER tool's
# source rather than restated here, so a rename on either side fails.
gate_schema="$(grep -o 'inspire\.suite-results/[0-9]*' "$BIN/lib/gate-results.sh" | head -1)"
eq "the emitted schema string is the one gate-results.sh demands" \
  "$(jq -r '.schema' "$produced")" "$gate_schema"

gate_statuses="$(grep -o '\.status == "[a-z]*"' "$BIN/lib/gate-results.sh" \
  | sed -e 's/.*"\(.*\)"/\1/' | LC_ALL=C sort -u | tr '\n' ' ')"
emitted_statuses="$( cd "$FX/skips" && bash "$RESULTS" --from jest-report.json 2>/dev/null \
  | jq -r '.tests[].status' | LC_ALL=C sort -u | tr '\n' ' ' )"
all_statuses="$( for d in "$FX"/*/; do
    [ -f "$d/expect.json" ] || continue
    [ "$(jq -r '.exit' "$d/expect.json")" = "0" ] || continue
    args=(); while IFS= read -r a; do args+=("$a"); done < <(jq -r '.args[]?' "$d/expect.json")
    ( cd "$d" && bash "$RESULTS" ${args[@]+"${args[@]}"} 2>/dev/null ) | jq -r '.tests[].status'
  done | LC_ALL=C sort -u | tr '\n' ' ' )"

eq "the skips fixture really emitted something to read a vocabulary from" \
  "$(printf '%s' "$emitted_statuses" | wc -w | tr -d ' ')" "2"
eq "every status the emitter can produce is one gate accepts" \
  "$all_statuses" "$gate_statuses"

# ─────────────────────────────────────────────────────────────────────────────
# Repo-relative paths — the join gate makes is against citations found under
# --tests-root, which are repo-relative; jest reports absolute paths.
# ─────────────────────────────────────────────────────────────────────────────

REPO="$WORK/proj"; mkdir -p "$REPO/test/accounts"
REPO_PHYS="$(cd "$REPO" && pwd -P)"
cat > "$WORK/abs-report.json" <<EOF
{ "testResults": [
    { "name": "$REPO_PHYS/test/accounts/account.e2e-spec.ts",
      "assertionResults": [
        { "fullName": "POST /accounts creates", "status": "passed" } ] } ] }
EOF

abs_out="$(bash "$RESULTS" --from "$WORK/abs-report.json" --root "$REPO_PHYS" 2>/dev/null)"
eq "an absolute jest path is stripped to a repo-relative one" \
  "$(printf '%s' "$abs_out" | jq -r '.tests[0].file')" "test/accounts/account.e2e-spec.ts"

# The unresolved spelling is the case macOS creates on its own (/var is a
# symlink to /private/var), and the one a naive `pwd -P` strip misses.
unresolved_out="$(bash "$RESULTS" --from "$WORK/abs-report.json" --root "$REPO" 2>/dev/null)"
eq "the same path strips when --root is given unresolved" \
  "$(printf '%s' "$unresolved_out" | jq -r '.tests[0].file')" "test/accounts/account.e2e-spec.ts"

# A path outside the root is left alone rather than mangled: nothing is
# gained by half-stripping a file the run does not own.
cat > "$WORK/foreign-report.json" <<'EOF'
{ "testResults": [
    { "name": "/opt/elsewhere/other.spec.ts",
      "assertionResults": [ { "fullName": "other", "status": "passed" } ] } ] }
EOF
foreign_out="$(bash "$RESULTS" --from "$WORK/foreign-report.json" --root "$REPO_PHYS" 2>/dev/null)"
eq "a path outside --root is carried through untouched" \
  "$(printf '%s' "$foreign_out" | jq -r '.tests[0].file')" "/opt/elsewhere/other.spec.ts"

# ─────────────────────────────────────────────────────────────────────────────
# Writes nothing
# ─────────────────────────────────────────────────────────────────────────────

W="$WORK/writes"; mkdir -p "$W"
cp -R "$FX/two-reports/." "$W/"

before="$(manifest "$W")"
w_out="$( cd "$W" && bash "$RESULTS" --from unit.json --from e2e.json 2>/dev/null )"
w_code=$?
after="$(manifest "$W")"

eq "the writes-nothing run really ran (exit 0, two tests parsed)" \
  "$w_code:$(printf '%s' "$w_out" | jq -r '.tests | length' 2>/dev/null)" "0:2"
eq "a full run leaves the tree it read byte- and mtime-identical" "$after" "$before"

eq "two runs over one report are byte-identical" \
  "$( cd "$W" && bash "$RESULTS" --from unit.json --from e2e.json 2>/dev/null | sha_of /dev/stdin | awk '{print $1}' )" \
  "$( cd "$W" && bash "$RESULTS" --from unit.json --from e2e.json 2>/dev/null | sha_of /dev/stdin | awk '{print $1}' )"

# ─────────────────────────────────────────────────────────────────────────────
# Stdout is EMPTY on every refusal, and stderr names the offending report
# ─────────────────────────────────────────────────────────────────────────────

# refuses <label> <want-exit> <arg>... — one refusal shape, asserted on both
# halves of the promise: the exit code AND that nothing reached stdout.
refuses() {
  local label="$1" want="$2"; shift 2
  local out code
  out="$(bash "$RESULTS" "$@" 2>/dev/null)"; code=$?
  eq "$label refuses with exit $want and EMPTY stdout" "$code:${#out}" "$want:0"
}

refuses "an unbuilt --format"        2 --from "$FX/all-green/jest-report.json" --format junit
refuses "an absent report"           3 --from "$WORK/no-such-report.json"
refuses "a JUnit XML report"         5 --from "$FX/xml-refused/junit.xml"
refuses "a non-JSON runner log"      5 --from "$FX/not-json-refused/runner.out"
refuses "an unknown test status"     5 --from "$FX/unknown-status-refused/jest-report.json"
refuses "a report with no file path" 5 --from "$FX/no-file-path-refused/jest-report.json"

# Two reports, the second bad: the message has to say which.
cp "$FX/all-green/jest-report.json" "$WORK/good.json"
cp "$FX/xml-refused/junit.xml" "$WORK/second-bad.xml"
err="$(bash "$RESULTS" --from "$WORK/good.json" --from "$WORK/second-bad.xml" 2>&1 >/dev/null)"
if printf '%s' "$err" | grep -Fq "second-bad.xml" && ! printf '%s' "$err" | grep -Fq "good.json"; then
  ok "a refusal names the offending report and not its healthy sibling"
else
  bad "a refusal names the offending report and not its healthy sibling (got: $err)"
fi

echo ""
echo "Total: $((pass + fail)) · Failed: $fail"
[ "$fail" -eq 0 ]
