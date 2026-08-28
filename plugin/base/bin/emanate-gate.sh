#!/usr/bin/env bash
# .inspire/bin/emanate-gate.sh
#
# gate — claim coverage x citing tests x suite result -> stdout VERDICT (D8).
# One of the emanation loop's four independent bin scripts (derive, plan,
# gate, harvest); composes on derive's OUTPUT only — it never calls
# emanate-derive.sh and never sources its lib/derive-*.sh, so the two
# packages can evolve independently. The shared bulk lives in
# `lib/gate-{contract,citations,results,verdict}.sh`.
#
# THE ORCHESTRATOR PROMOTES. GATE PRODUCES THE EVIDENCE (design's inherited
# shape, ~line 31): this script writes nothing, runs no suite (D4 — "never
# trusting a persona's green" is exactly why the results are HANDED IN rather
# than reproduced here), edits no frontmatter and never writes `lifecycle:`.
# An approval is necessary, never sufficient (D3); this is the deterministic
# half a rejection alone cannot stand in for.
#
# Usage:
#   emanate-gate.sh --contract FILE|-  --results FILE
#                   [--tests-root DIR]...  [--previous FILE]
#
#   --contract   the derived contract (emanate-derive.sh's stdout), one JSON
#                object; `-` reads stdin. Required.
#   --results    the suite results, `inspire.suite-results/1` (a JSON
#                manifest the orchestrator produces — R1, JUnit's file<->test
#                binding is too unreliable across runners for gate to read
#                on its own). Required.
#   --tests-root DIR
#                repeatable. The tree(s) grepped for `@claim` tokens.
#                Defaults to `tests` (CWD-relative) when none given. Gate
#                never resolves a stack profile's own test-path convention
#                (R2) — this is always an argument, never a guess.
#   --previous FILE
#                the previous run's derived contract, for the `delta` (joined
#                by claim id, never array order — N8).
#   -h|--help    this text.
#
# CWD is the repo root, as everywhere in base/bin/. Gate reads NO KB and
# needs neither $SDD_KB_ROOT nor $SDD_SPEC_ROOT.
#
# Exit codes — distinct and documented, never a generic catch-all:
#   0    PASS — no finding. Verdict on stdout.
#   1    FAIL — one or more findings. Verdict on stdout: a normal outcome the
#        orchestrator branches on, not a crash.
#   2    usage — unknown flag, missing --contract or --results.
#   3    an input path does not exist or is unreadable (contract, results, a
#        --tests-root, --previous), or a discovered test path gate cannot
#        address (a `:` or a newline in its name — symlinks/exotic paths are
#        a declared non-support, CLAUDE.md).
#   4    the contract is unusable: a derive refusal object, or a foreign/
#        missing schema. Stdout still carries a verdict — `verdict: "fail"`,
#        the refusal rows under class GV-00, an empty claims[] — because a
#        unit that did not derive cannot be gated, and the verdict's own
#        grammar says so better than silence would.
#   5    the results file is not `inspire.suite-results/1` (D7's strictness,
#        applied to gate's own input: an old or foreign shape is an error,
#        never a silently-empty section — a silent misread would mark every
#        claim not-run, the vacuity trap in a new coat).
#   127  a required tool is missing (jq).
#
# Stdout is valid JSON on every exit that produces a verdict (0, 1, 4) and
# EMPTY on 2, 3, 5, 127. Stderr carries the grouped human report
# (`GATE pass|fail <kind> <id>`, findings by class, a counts tail) mirroring
# emanate-derive.sh's report_refusals/report_derived.
#
# The GV-* catalogue, the verdict schema, the suite-results schema and every
# exit code: `.claude/skills/_references/gate-verdict.md`.
#
# WRITES NOTHING. No file, no log, no KB edit, no git state, no suite run — a
# scratch directory under $TMPDIR is all, and the EXIT trap removes it.

set -uo pipefail

EXIT_OK=0
EXIT_FAIL=1
EXIT_USAGE=2
EXIT_INPUT=3
EXIT_CONTRACT=4
EXIT_RESULTS=5
EXIT_MISSING_TOOL=127

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The header block's own Usage/Exit-codes/Report sections, through to (but
# not including) "The GV-* catalogue" — the doc pointer is not itself help
# text a caller needs repeated on a terminal.
usage() {
  sed -n '/^# Usage:/,/^# The GV-\* catalogue/p' "$0" \
    | sed -e '/^# The GV-\* catalogue/d' -e '/^[^#]/d' -e 's/^# \{0,1\}//'
}

die_code() {
  local code="$1"; shift
  echo "emanate-gate.sh: $*" >&2
  exit "$code"
}

require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  echo "emanate-gate.sh: missing required tool: jq" >&2
  echo "                 install via: brew install jq" >&2
  exit "$EXIT_MISSING_TOOL"
}

source "$SCRIPT_DIR/lib/gate-contract.sh"
source "$SCRIPT_DIR/lib/gate-citations.sh"
source "$SCRIPT_DIR/lib/gate-results.sh"
source "$SCRIPT_DIR/lib/gate-verdict.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

CONTRACT=""; RESULTS=""; PREVIOUS=""
TESTS_ROOTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --contract) [ $# -ge 2 ] || die_code "$EXIT_USAGE" "--contract needs a value"; CONTRACT="$2"; shift 2 ;;
    --results)  [ $# -ge 2 ] || die_code "$EXIT_USAGE" "--results needs a value"; RESULTS="$2"; shift 2 ;;
    --tests-root) [ $# -ge 2 ] || die_code "$EXIT_USAGE" "--tests-root needs a value"; TESTS_ROOTS+=("$2"); shift 2 ;;
    --previous) [ $# -ge 2 ] || die_code "$EXIT_USAGE" "--previous needs a value"; PREVIOUS="$2"; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    -*) die_code "$EXIT_USAGE" "unknown option: $1" ;;
    *) die_code "$EXIT_USAGE" "unexpected argument: $1" ;;
  esac
done

[ -n "$CONTRACT" ] || die_code "$EXIT_USAGE" "--contract is required"
[ -n "$RESULTS" ] || die_code "$EXIT_USAGE" "--results is required"

require_jq

[ "${#TESTS_ROOTS[@]}" -gt 0 ] || TESTS_ROOTS=("tests")

# Every input path is validated before anything is read: usage-adjacent and
# cheap, and exit 4/5's content judgments never have to depend on whether an
# UNRELATED flag happens to point at something real.
for r in "${TESTS_ROOTS[@]}"; do
  [ -d "$r" ] || die_code "$EXIT_INPUT" "--tests-root does not exist: $r"
done
if [ "$CONTRACT" != "-" ]; then
  [ -f "$CONTRACT" ] && [ -r "$CONTRACT" ] || die_code "$EXIT_INPUT" "--contract file not found or unreadable: $CONTRACT"
fi
[ -f "$RESULTS" ] && [ -r "$RESULTS" ] || die_code "$EXIT_INPUT" "--results file not found or unreadable: $RESULTS"
if [ -n "$PREVIOUS" ]; then
  [ -f "$PREVIOUS" ] && [ -r "$PREVIOUS" ] || die_code "$EXIT_INPUT" "--previous file not found or unreadable: $PREVIOUS"
fi

GATE_TMP="$(mktemp -d -t emanate-gate.XXXXXX)" || die_code "$EXIT_INPUT" "cannot create a scratch directory"
trap 'rm -rf "${GATE_TMP:-}"' EXIT

if [ "$CONTRACT" = "-" ]; then
  cat > "$GATE_TMP/contract.json"
else
  cat "$CONTRACT" > "$GATE_TMP/contract.json"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Contract first: an unusable one short-circuits before results/citations are
# even touched — there is nothing left to join against.
# ─────────────────────────────────────────────────────────────────────────────

gate_contract_load "$GATE_TMP/contract.json"

if [ "$GATE_CONTRACT_STATUS" != "ok" ]; then
  gate_render_refused
  cat "$GATE_TMP/verdict.json"
  gate_report_stderr "$GATE_TMP/verdict.json"
  exit "$EXIT_CONTRACT"
fi

gate_load_results "$RESULTS"
gate_collect_citations "$GATE_UNIT_ID" "$GATE_TMP/claim-ids.txt" "${TESTS_ROOTS[@]}"

have_previous="false"
if [ -n "$PREVIOUS" ]; then
  gate_contract_load_previous "$PREVIOUS"
  have_previous="true"
fi

gate_check_no_match_diagnostic
gate_render_verdict "$GATE_UNIT_ID" "$have_previous" "$RESULTS"

verdict="$(jq -r '.verdict' "$GATE_TMP/verdict.json")"
cat "$GATE_TMP/verdict.json"
gate_report_stderr "$GATE_TMP/verdict.json"

[ "$verdict" = "pass" ] && exit "$EXIT_OK"
exit "$EXIT_FAIL"
