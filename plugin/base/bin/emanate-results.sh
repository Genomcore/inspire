#!/usr/bin/env bash
# .inspire/bin/emanate-results.sh
#
# results — a test runner's own report -> the `inspire.suite-results/1`
# manifest on stdout (D8). A tool, not a review rule: it emits no findings and
# is deliberately absent from review.sh's DEFAULT_RULES, exactly like
# emanate-{derive,plan,gate,harvest}.sh and trust.sh.
#
# WHY THIS EXISTS. `emanate-gate.sh --results` reads one shape and one only —
# `inspire.suite-results/1`, because JUnit's file<->test binding is too
# unreliable across runners for gate to read on its own (R1). Something has to
# produce that manifest from what a real runner actually prints, and leaving it
# to the orchestrator's judgement would put a schema in a prose doctrine: the
# one place a persona could hand gate a plausible-but-wrong shape and have
# every claim silently read as not-run. This script is that step, deterministic
# and goldened.
#
# THE MANIFEST IS NOT DEFINED HERE. Its authority is
# `lib/gate-results.sh` (the reader) and `_references/gate-verdict.md`
# (the document): top-level `schema` exactly once, `tests[]`, and per entry
# `file` + `name` + `status` in {passed,failed,skipped}, `message` optional.
# This script emits that and nothing it invents.
#
# Usage:
#   emanate-results.sh --from FILE [--from FILE]... [--format jest]
#                      [--root DIR]
#
#   --from FILE  a runner report. Repeatable, and order-preserving: the
#                shipped stack runs its unit and e2e suites as two commands,
#                so two reports are the normal case, not an edge one.
#                Required.
#   --format ID  the report dialect. `jest` (the default) is the only one
#                built: it is what the shipped `nestjs` profile's
#                `## Build & verify` commands produce. A second dialect would
#                be another reader function in this file — the extension point
#                is named so that handing it an unbuilt one refuses loudly
#                instead of misreading.
#   --root DIR   strip this prefix from every test file path, so the manifest
#                carries repo-relative paths. Defaults to the CWD (the repo
#                root, as everywhere in base/bin/). Load-bearing: gate joins
#                the manifest's `file` against `@claim` citations found under
#                its --tests-root, which are repo-relative, and jest reports
#                absolute paths. A path already relative is left alone.
#   -h|--help    this text.
#
# THE RECIPE, for the shipped jest-based runner (nestjs profile). `--json`
# with `--outputFile` rather than stdout: the suite's own console output and
# the report would otherwise share a stream, and `|| true` because a runner
# exits non-zero on a red suite and a red suite is exactly the case whose
# report gate needs:
#
#   npm run test     -- --json --outputFile="$T/unit.json"  || true
#   npm run test:e2e -- --json --outputFile="$T/e2e.json"   || true
#   emanate-results.sh --from "$T/unit.json" --from "$T/e2e.json" > results.json
#
# Status mapping — jest's six assertion statuses onto the schema's three.
# `pending`/`todo`/`disabled` are all "declared and not executed", which is
# what `skipped` means to gate (GV-02: a claim whose only citing test was
# skipped is NOT covered):
#   passed                        -> passed
#   failed                        -> failed
#   pending | todo | disabled     -> skipped
#   focused                       -> passed   (it ran; `.only` is a local
#                                              habit, not a result)
# Anything else refuses (exit 5) rather than be folded into a bucket: an
# unrecognised status quietly read as `skipped` is the vacuity trap in a new
# coat, the same one gate-results.sh's XML sniff exists to close.
#
# Exit codes — distinct and documented, never a generic catch-all:
#   0    a manifest was written to stdout.
#   2    usage — unknown flag, no --from, an unbuilt --format.
#   3    a --from file does not exist or is unreadable, or --root is not a
#        directory.
#   5    a report is not a shape this reader accepts: XML, unparseable JSON,
#        no `testResults` array, an entry with no file path, or an unknown
#        assertion status. Mirrors gate's own EXIT_RESULTS — an old or
#        foreign shape is an error, never a silently-empty manifest.
#   127  a required tool is missing (jq).
#
# Stdout is the manifest, and EMPTY on every non-zero exit. Stderr carries a
# one-line counts report, mirroring the other emanate-* tools' grouped reports.
#
# WRITES NOTHING. No file, no log, no KB edit, no git state, no suite run — a
# scratch directory under $TMPDIR is all, and the EXIT trap removes it.
#
# In-package decision: lib/. The `emanate-*` scripts share `bin/lib/`, and a
# `results-*.sh` unit was considered and rejected: this script has exactly one
# reader function and one caller, and the manifest's schema knowledge already
# has a home in `lib/gate-results.sh`. A lib unit here would be indirection
# for a single call site — harvest's own reasoning, unchanged.

set -uo pipefail

EXIT_OK=0
EXIT_USAGE=2
EXIT_INPUT=3
EXIT_RESULTS=5
EXIT_MISSING_TOOL=127

# The header's Usage/recipe/mapping/exit sections, through to (but not
# including) the in-package rationale, which is not operator-facing help.
usage() {
  sed -n '/^# Usage:/,/^# In-package decision/p' "$0" \
    | sed -e '/^# In-package decision/d' -e '/^[^#]/d' -e 's/^# \{0,1\}//'
}

die_code() {
  local code="$1"; shift
  echo "emanate-results.sh: $*" >&2
  exit "$code"
}

require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  echo "emanate-results.sh: missing required tool: jq" >&2
  echo "                    install via: brew install jq" >&2
  exit "$EXIT_MISSING_TOOL"
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

FORMAT="jest"
ROOT=""
FROM=()

while [ $# -gt 0 ]; do
  case "$1" in
    --from)   [ $# -ge 2 ] || die_code "$EXIT_USAGE" "--from needs a value"; FROM+=("$2"); shift 2 ;;
    --format) [ $# -ge 2 ] || die_code "$EXIT_USAGE" "--format needs a value"; FORMAT="$2"; shift 2 ;;
    --root)   [ $# -ge 2 ] || die_code "$EXIT_USAGE" "--root needs a value"; ROOT="$2"; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    -*) die_code "$EXIT_USAGE" "unknown option: $1" ;;
    *)  die_code "$EXIT_USAGE" "unexpected argument: $1" ;;
  esac
done

[ "${#FROM[@]}" -gt 0 ] || die_code "$EXIT_USAGE" "--from is required"
[ "$FORMAT" = "jest" ] \
  || die_code "$EXIT_USAGE" "unknown --format: '$FORMAT' (jest is the only dialect built; JUnit is deliberately not read — see emanate-gate.sh)"

require_jq

[ -n "$ROOT" ] || ROOT="$PWD"
[ -d "$ROOT" ] || die_code "$EXIT_INPUT" "--root is not a directory: $ROOT"
# Both spellings are stripped, and neither is redundant: `pwd -P` resolves
# symlinks (/var -> /private/var on macOS), so a runner invoked through the
# unresolved path emits paths the physical root does not prefix, and one
# invoked through a resolved one emits paths the literal root does not.
ROOT_LIT="${ROOT%/}"; [ -n "$ROOT_LIT" ] || ROOT_LIT="/"
ROOT_PHYS="$(cd "$ROOT" && pwd -P)" || die_code "$EXIT_INPUT" "cannot resolve --root: $ROOT"

for f in "${FROM[@]}"; do
  [ -f "$f" ] && [ -r "$f" ] || die_code "$EXIT_INPUT" "--from file not found or unreadable: $f"
done

WORK="$(mktemp -d -t emanate-results.XXXXXX)" || die_code "$EXIT_INPUT" "cannot create a scratch directory"
trap 'rm -rf "${WORK:-}"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
# The jest reader. One NDJSON entry per assertion appended to the spool, so
# several reports merge in argument order without any of them being re-read.
# ─────────────────────────────────────────────────────────────────────────────

SPOOL="$WORK/tests.ndjson"
: > "$SPOOL"

# read_jest <file> — appends this report's entries to $SPOOL, or dies (5).
# Every refusal names the file: two reports are the normal case, so "which
# one" is the first thing an operator needs.
read_jest() {
  local file="$1" first

  first="$(LC_ALL=C tr -d '[:space:]' < "$file" 2>/dev/null | head -c1)"
  [ "$first" != "<" ] \
    || die_code "$EXIT_RESULTS" "$file looks like XML; emanate-results.sh reads a jest --json report (JUnit is not read — see emanate-gate.sh)"

  jq -e 'has("testResults") and (.testResults | type == "array")' "$file" >/dev/null 2>&1 \
    || die_code "$EXIT_RESULTS" "$file is not a jest --json report (no testResults array)"

  # `name` is what jest's own json formatter calls the test file path;
  # `testFilePath` is the field some reporters emit instead.
  jq -c --arg root "$ROOT_LIT" --arg rootp "$ROOT_PHYS" '
    def relpath($p):
      (if   ($p | startswith($root  + "/")) then ($p | ltrimstr($root  + "/"))
       elif ($p | startswith($rootp + "/")) then ($p | ltrimstr($rootp + "/"))
       else $p end)
      | ltrimstr("./");
    def statusmap($s):
      if   $s == "passed"  or $s == "focused"                     then "passed"
      elif $s == "failed"                                         then "failed"
      elif $s == "pending" or $s == "todo" or $s == "disabled"
        or $s == "skipped"                                        then "skipped"
      else error("unknown assertion status: " + $s) end;
    .testResults[]
    | (.name // .testFilePath) as $f
    | if ($f | type) != "string" or ($f | length) == 0
      then error("a testResults entry carries no file path")
      else . end
    | (.assertionResults // [])[]
    | { file: relpath($f),
        name: (.fullName // (((.ancestorTitles // []) + [(.title // "")]) | join(" ") | ltrimstr(" "))),
        status: statusmap(.status),
        message: ((.failureMessages // []) | join("\n")) }
    # gate reads `.message // ""`, so an empty one is noise in the manifest.
    | if .message == "" then del(.message) else . end
  ' "$file" >> "$SPOOL" 2>"$WORK/jq.err" \
    || die_code "$EXIT_RESULTS" "$file: $(sed -e 's/^jq: error ([^)]*): //' -e 's/^jq: error: //' "$WORK/jq.err" | head -1)"
}

for f in "${FROM[@]}"; do
  read_jest "$f"
done

# ─────────────────────────────────────────────────────────────────────────────
# Emit
# ─────────────────────────────────────────────────────────────────────────────

# Assembled whole, then printed — emanate-gate.sh's own order, and what makes
# "stdout is EMPTY on every non-zero exit" structural rather than argued.
MANIFEST="$WORK/results.json"
jq -s '{schema: "inspire.suite-results/1", tests: .}' "$SPOOL" > "$MANIFEST" \
  || die_code "$EXIT_RESULTS" "cannot assemble the manifest"

cat "$MANIFEST"

IFS=$'\t' read -r n_total n_passed n_failed n_skipped < <(jq -r '
  .tests
  | [ length,
      ([.[] | select(.status == "passed")]  | length),
      ([.[] | select(.status == "failed")]  | length),
      ([.[] | select(.status == "skipped")] | length) ]
  | @tsv' "$MANIFEST")

{
  printf 'INSPIRE results — %s test(s) from %s report(s): %s passed, %s failed, %s skipped\n' \
    "$n_total" "${#FROM[@]}" "$n_passed" "$n_failed" "$n_skipped"
  # Not a refusal: an empty manifest is a legal input gate reads as "every
  # claim not-run" and fails on. It is still almost always a misconfigured
  # runner, so it is said out loud here rather than discovered at the verdict.
  [ "$n_total" -gt 0 ] || printf '  warning: the report(s) contain no tests — every claim will read as not-run.\n'
} >&2

exit "$EXIT_OK"
