#!/usr/bin/env bash
# .inspire/bin/emanate-plan.sh
#
# plan — the frontier snapshot and every readiness check, for one scope
# (D5/D8/D10). Ordering the units is not done here: the INSPIRE factory's
# planner (Genomcore/inspire-factory) does it, on derive's output too. One of
# the emanation loop's five independent bin scripts (derive, plan, gate,
# results, harvest); the shared bulk lives in `lib/plan-{lib,scan,stack,
# realize,checks,report}.sh`, plus `lib/gate-citations.sh` — the `@claim` token
# has one scanner and two readings, coverage for gate and realization here.
#
# It COMPOSES ON DERIVE: one `emanate-derive.sh` run per frontier unit, read
# from stdout and nothing else. `derived-contract.md` draws that line:
# "`/inspire-emanate plan` aggregates the stdout objects — it must never parse
# stderr". So an old shape is derive's refusal, restated here as a readiness
# finding rather than re-detected.
#
# The frontier is every unit at `lifecycle: accepted` within the scope: design
# closed, contract being implemented, which is exactly what emanates. `draft` is
# still in design, `stable` is already delivered, `superseded` is history. A
# catalog entry says the same thing on its `**State:**` line, `to-extract`
# standing in for `accepted` and `implemented` for `stable`.
#
# The stdout JSON shape, the `PR-*` catalogue, the frontier rule and the edge
# rule: `.claude/skills/_references/emanation-plan.md`.
#
# Usage:
#   emanate-plan.sh [--scope PATH]... [--tests-root DIR]...
#                   [--reemanate SEL]... [--goal SEL]
#                   [--profiles-root DIR] [--agents-root DIR]
#
#   --scope PATH   repeatable. A KB path — a directory or a single file —
#                  intersected with each layer through the same scope contract
#                  every rule obeys. Omitted: the whole knowledge base.
#   --tests-root DIR
#                  repeatable. The tree(s) walked for `@claim` tokens, to work
#                  out which units are already REALIZED (D9). Realized units
#                  leave the frontier and satisfy edges like a `stable`
#                  artifact. There is NO DEFAULT: given none, no tests tree is
#                  read and no unit is realized — plan never guesses which tree
#                  holds a project's tests.
#   --reemanate SEL
#                  repeatable. Treat the units SEL names as unrealized for this
#                  run. SEL is an id, a glob over ids, `X..` (X and its
#                  transitive dependents) or `X..Y` (every node on an ordering
#                  path from X to Y, inclusive). Closures walk ORDERING edges
#                  only — a navigation edge never extends one.
#   --goal SEL     the run's target, same selector grammar. The plan then also
#                  names the goal's remaining dependency closure.
#   --profiles-root DIR  where the stack profiles live. Default
#                  `.claude/skills/inspire-code/profiles`, env override
#                  $INSPIRE_PROFILES_ROOT.
#   --agents-root DIR    where the agent shells live. Default `.claude/agents`,
#                  env override $INSPIRE_AGENTS_ROOT.
#
# There is no --mode: plan is read-only unconditionally, which is the opposite
# of harvest's posture and the reason this script has no act half to guard.
#
# Roots, as everywhere in base/bin/: the current working directory is the repo
# root; $SDD_SPEC_ROOT (default inspire_kb/04_domain) is the domain tree and
# $SDD_KB_ROOT (default inspire_kb) is the KB as a whole. Both are required:
# actions and entities live in one, screens and the stack in the other.
#
# Exit codes — distinct and documented, never a generic catch-all:
#   0    READY. A plan, and no error-severity finding. Stdout carries it.
#   1    NOT READY. A plan was computed and at least one finding is an error.
#        The verdict vocabulary is `review.sh`'s, not an internal-failure code.
#   2    usage — unknown flag, a --scope or --tests-root path
#        that is not there, a --tests-root holding a path this tool cannot
#        address, a --reemanate/--goal selector that selects nothing (no unit in
#        the frontier answers to an endpoint, or a segment's endpoints both
#        resolve with no ordering path between them in that direction), or
#        -h/--help.
#   4    REFUSED. A precondition of planning failed and nothing is planned.
#        Stdout carries every class found, not the first.
#   5    roots missing — $SDD_KB_ROOT or $SDD_SPEC_ROOT is not a directory.
#   6    internal — a `derive` run exited outside {0,4}, or produced no readable
#        contract. Defensive: every input it could refuse over is checked first.
#   127  a required tool is missing (jq, yq, or a sha256 digest).
#
# Stdout is JSON on exactly the exits that produce a verdict, and EMPTY on every
# other one:
#   exit 0 / 1   {schema, scope, ready, realized, realized_all, reemanate, goal,
#                 preflight, wire_conventions, units: [...], findings}
#   exit 4       {schema, scope, ready: false, refused: [...]} — and no `units`
#                key at all, because nothing was planned and an empty key would
#                read as "planned, and it is empty".
# Stderr carries the grouped human report.
#
# WRITES NOTHING — no file, no log, no KB edit, no git state, and not
# `.inspire/last-emanation.log` either (D11: "plan writes nothing, that file
# included"). A scratch directory under $TMPDIR is all, and the EXIT trap
# removes it.
#
# Internals: every refusal — the stack, the overseer roster, an empty frontier
# — needs no derivation, and each class found is reported. Deriving a vault to
# discover that the overseer roster is broken would be work whose answer nothing
# could use. A cycle in the ordering edges is the factory planner's refusal.
#
# EMPTINESS SPLITS ACROSS THE DERIVATION, and it has to: nothing being
# `accepted` is knowable before one and REFUSES (`PR-12`), while everything
# being realized is knowable only after one and SUCCEEDS — exit 0, `units: []`,
# `realized_all: true` ("the goal is already met"). The two answers are opposite
# on purpose: one says there is nothing to build, the other that there is
# nothing LEFT to build.

set -uo pipefail

EXIT_OK=0
EXIT_NOT_READY=1
EXIT_USAGE=2
EXIT_REFUSED=4
EXIT_NO_ROOTS=5
EXIT_INTERNAL=6
EXIT_MISSING_TOOL=127

PLAN_SCHEMA="inspire.emanation-plan/3"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAN_BIN="$SCRIPT_DIR"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_keyed-heads.sh"
source "$SCRIPT_DIR/lib/plan-lib.sh"
source "$SCRIPT_DIR/lib/plan-scan.sh"
source "$SCRIPT_DIR/lib/plan-stack.sh"
# The `@claim` scanner is gate's and is SHARED rather than reimplemented: one
# grammar, two readers (coverage there, realization here).
source "$SCRIPT_DIR/lib/gate-citations.sh"
source "$SCRIPT_DIR/lib/plan-realize.sh"
source "$SCRIPT_DIR/lib/plan-checks.sh"
source "$SCRIPT_DIR/lib/plan-report.sh"

# The header block's own Usage and Exit-codes sections, through to (but not
# including) "Internals" — the tiering rationale is not operator-facing help.
usage() {
  sed -n '/^# Usage:/,/^# Internals:/p' "$0" \
    | sed -e '/^# Internals:/d' -e '/^[^#]/d' -e 's/^# \{0,1\}//'
}

die_usage() {
  echo "emanate-plan.sh: $*" >&2
  usage >&2
  exit "$EXIT_USAGE"
}

PLAN_BROKE=""
PLAN_BAD_SELECTOR=""
PLAN_SEL_REASON=""
PLAN_GOAL=""
PLAN_REALIZED_ALL=false
PLAN_READY=true
PLAN_PROFILES_ROOT="${INSPIRE_PROFILES_ROOT:-.claude/skills/inspire-code/profiles}"
PLAN_AGENTS_ROOT="${INSPIRE_AGENTS_ROOT:-.claude/agents}"
PLAN_SCOPE_ARGS=""
PLAN_REEMANATE_ARGS=""
PLAN_TESTS_ROOTS=()

add_scope() {
  [ -e "$1" ] || die_usage "no such --scope path: $1"
  PLAN_SCOPE_ARGS="${PLAN_SCOPE_ARGS}$(sdd_scope_norm "$1")
"
}

add_tests_root() {
  [ -d "$1" ] || die_usage "--tests-root is not a directory: $1"
  PLAN_TESTS_ROOTS+=("$1")
}

# A selector's SHAPE is checked here; whether it names anything is a question
# for the frontier, which does not exist yet.
check_selector() {
  case "$2" in
    '')   die_usage "$1 needs a selector" ;;
    ..*)  die_usage "$1 selector has no left-hand node: '$2'" ;;
    *..*..*) die_usage "$1 selector names more than one segment: '$2'" ;;
  esac
}

add_reemanate() {
  check_selector --reemanate "$1"
  PLAN_REEMANATE_ARGS="${PLAN_REEMANATE_ARGS}$1
"
}

set_goal() {
  check_selector --goal "$1"
  [ -z "$PLAN_GOAL" ] || die_usage "--goal may be given once: '$PLAN_GOAL' then '$1'"
  PLAN_GOAL="$1"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --scope)         [ $# -ge 2 ] || die_usage "--scope needs a path"; add_scope "$2"; shift 2 ;;
    --scope=*)       add_scope "${1#--scope=}"; shift ;;
    --tests-root)    [ $# -ge 2 ] || die_usage "--tests-root needs a directory"
                     add_tests_root "$2"; shift 2 ;;
    --tests-root=*)  add_tests_root "${1#--tests-root=}"; shift ;;
    --reemanate)     [ $# -ge 2 ] || die_usage "--reemanate needs a selector"
                     add_reemanate "$2"; shift 2 ;;
    --reemanate=*)   add_reemanate "${1#--reemanate=}"; shift ;;
    --goal)          [ $# -ge 2 ] || die_usage "--goal needs a selector"; set_goal "$2"; shift 2 ;;
    --goal=*)        set_goal "${1#--goal=}"; shift ;;
    --profiles-root) [ $# -ge 2 ] || die_usage "--profiles-root needs a directory"
                     PLAN_PROFILES_ROOT="$2"; shift 2 ;;
    --profiles-root=*) PLAN_PROFILES_ROOT="${1#--profiles-root=}"; shift ;;
    --agents-root)   [ $# -ge 2 ] || die_usage "--agents-root needs a directory"
                     PLAN_AGENTS_ROOT="$2"; shift 2 ;;
    --agents-root=*) PLAN_AGENTS_ROOT="${1#--agents-root=}"; shift ;;
    -h|--help)       usage >&2; exit "$EXIT_USAGE" ;;
    -*)              die_usage "unknown option: $1" ;;
    *)               die_usage "unexpected argument: $1" ;;
  esac
done

sdd_require_tools || exit "$EXIT_MISSING_TOOL"
# Checked here rather than left to derive: a tool missing under a fan-out would
# surface as a dozen unreadable contracts instead of one legible refusal.
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
  echo "emanate-plan.sh: missing required tool: sha256sum or shasum" >&2
  exit "$EXIT_MISSING_TOOL"
fi

[ -d "$SDD_KB_ROOT" ] || {
  echo "emanate-plan.sh: \$SDD_KB_ROOT ($SDD_KB_ROOT) is not a directory — not a knowledge base" >&2
  exit "$EXIT_NO_ROOTS"; }
[ -d "$SDD_SPEC_ROOT" ] || {
  echo "emanate-plan.sh: \$SDD_SPEC_ROOT ($SDD_SPEC_ROOT) is not a directory — not a knowledge base" >&2
  exit "$EXIT_NO_ROOTS"; }

# `_lib.sh` defaults these without exporting them, and every derivation is a
# child process that has to read the same two roots this run did.
export SDD_KB_ROOT SDD_SPEC_ROOT

plan_scratch >/dev/null || exit "$EXIT_MISSING_TOOL"
trap 'rm -rf "$PLAN_TMP"' EXIT
plan_init_spools units requires profiles findings refused \
                 components probes recipe wireids wirerows
# Every list the renderers read has to EXIST before the run can take a path that
# skips filling it: `--rawfile` fails on a missing file, and "there were none"
# must not read as a broken run.
: > "$PLAN_TMP/realized"; : > "$PLAN_TMP/realized.delivered"
: > "$PLAN_TMP/goal.units"
: > "$PLAN_TMP/components.tsv"; : > "$PLAN_TMP/probes"; : > "$PLAN_TMP/recipe.tsv"
# Sorted and deduplicated before anything reads it: two --scope flags name one
# vault, so neither the order they were typed in nor a repeat may reach stdout.
printf '%s' "$PLAN_SCOPE_ARGS" | LC_ALL=C sort -u > "$PLAN_TMP/scopes"
# The selector list keeps the order it was typed in: the sets are unioned, so
# order changes nothing, and re-sorting would only make the error message name a
# different selector than the operator's first mistake.
printf '%s' "$PLAN_REEMANATE_ARGS" > "$PLAN_TMP/reemanate-args"
if [ -s "$PLAN_TMP/scopes" ]; then
  cp "$PLAN_TMP/scopes" "$PLAN_TMP/scopes.out"
else
  # The default sweep walks both roots, so the label names both — unless the
  # spec root sits inside the KB root, as it does in a deployed vault.
  { sdd_scope_norm "$SDD_KB_ROOT"
    plan_under "$(sdd_scope_norm "$SDD_SPEC_ROOT")" "$(sdd_scope_norm "$SDD_KB_ROOT")" \
      || sdd_scope_norm "$SDD_SPEC_ROOT"
  } | LC_ALL=C sort -u > "$PLAN_TMP/scopes.out"
fi
PLAN_SCOPE_LABEL="$(plan_norm "$(tr '\n' ' ' < "$PLAN_TMP/scopes.out")")"

# ─────────────────────────────────────────────────────────────────────────────
# Refusals — the preconditions no derivation is needed to answer
# ─────────────────────────────────────────────────────────────────────────────

plan_scan
refused=0
plan_check_stack     || refused=1
plan_check_overseers || refused=1
plan_check_frontier  || refused=1
if [ "$refused" = 1 ]; then
  plan_json_refused
  plan_report_refused
  exit "$EXIT_REFUSED"
fi

# ─────────────────────────────────────────────────────────────────────────────
# One derivation per frontier unit, realization, then the edges
# ─────────────────────────────────────────────────────────────────────────────

plan_derive_all
plan_ingest || { echo "emanate-plan.sh: $PLAN_BROKE" >&2; exit "$EXIT_INTERNAL"; }
plan_realize || { echo "emanate-plan.sh: $PLAN_BROKE" >&2; exit "$EXIT_USAGE"; }
plan_apply_reemanate || {
  echo "emanate-plan.sh: $PLAN_BAD_SELECTOR $PLAN_SEL_REASON" >&2
  exit "$EXIT_USAGE"; }
plan_narrow
plan_resolve_edges

if [ -n "$PLAN_GOAL" ]; then
  plan_goal "$PLAN_GOAL" || {
    echo "emanate-plan.sh: $PLAN_BAD_SELECTOR $PLAN_SEL_REASON" >&2
    exit "$EXIT_USAGE"; }
fi

# ─────────────────────────────────────────────────────────────────────────────
# Verdict
# ─────────────────────────────────────────────────────────────────────────────

plan_check_profiles
plan_check_preflight
plan_check_reachable

# The frontier is empty because everything in it is already realized: the
# success case, not `PR-12`'s refusal. `PR-12` fired before derive or not at all.
[ -s "$PLAN_TMP/nodes" ] || PLAN_REALIZED_ALL=true

if awk -F"$PLAN_FS" '$2 == "error" { f = 1; exit } END { exit !f }' "$PLAN_TMP/findings.spool"; then
  PLAN_READY=false
fi

plan_json_plan
plan_report_plan
[ "$PLAN_READY" = true ] || exit "$EXIT_NOT_READY"
exit "$EXIT_OK"
