#!/usr/bin/env bash
# plugin/base/bin/test/test-plan-schema.sh — that the shipped schema still
# describes what `emanate-plan.sh` actually prints.
#
# `schemas/emanation-plan.schema.json` is the plan's canonical contract. Its
# TypeScript and Python renderings live with their consumer, the INSPIRE
# factory, which keeps them in sync with this file. A stale schema is worse than
# none: it type-checks a consumer against a shape the emitter stopped producing.
#
# So this asserts the DIRECTION that actually breaks — emitter first, document
# second. It runs the real script over real fixtures, walks the keys it emitted,
# and requires each to be declared in the schema. A field added to the jq program
# without a matching line in the schema files fails here, naming the key.
#
# What it deliberately does NOT do is validate the document against the JSON
# Schema: that needs a validator this estate does not otherwise want, and the
# breakage it would catch beyond key drift — a value of the wrong type — is one
# the goldens already pin per scenario.
#
# Usage: bash plugin/base/bin/test/test-plan-schema.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
BIN="$HERE/.."
FX="$HERE/fixtures/emanate-plan"
SCHEMAS="$BIN/schemas"
JSON_SCHEMA="$SCHEMAS/emanation-plan.schema.json"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

TMP="$(mktemp -d -t inspire-plan-schema.XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# plan_in <fixture> [args...] — one real run, stdout only.
plan_in() {
  local fx="$1"; shift
  ( cd "$FX/$fx" && SDD_KB_ROOT=spec/kb SDD_SPEC_ROOT=spec/sdd \
      bash "$BIN/emanate-plan.sh" --profiles-root spec/profiles \
           --agents-root spec/agents "$@" 2>/dev/null )
}

# declared_keys <def> — the property names one `$defs` entry declares.
declared_keys() {
  jq -r --arg d "$1" '.["$defs"][$d].properties | keys_unsorted[]' "$JSON_SCHEMA" \
    | LC_ALL=C sort
}

# emitted_keys <file> <jq-path> — the keys the emitter actually produced there.
emitted_keys() {
  jq -r "$2 | keys_unsorted[]" "$1" | LC_ALL=C sort -u
}

# same_keys <label> <def> <file> <jq-path> — the whole point of the file.
same_keys() {
  local label="$1" def="$2" file="$3" path="$4"
  eq "$label: the schema declares exactly the keys the emitter prints" \
    "$(emitted_keys "$file" "$path" | tr '\n' ',')" \
    "$(declared_keys "$def" | tr '\n' ',')"
}

# ─────────────────────────────────────────────────────────────────────────────
# The plan document, over a fixture rich enough to reach every branch
# ─────────────────────────────────────────────────────────────────────────────

plan_in canonical-example > "$TMP/plan.json"
eq "the canonical fixture still plans" "$(jq -r '.schema' "$TMP/plan.json")" \
  "inspire.emanation-plan/3"

same_keys "plan"     plan            "$TMP/plan.json" '.'
same_keys "unit"     unit            "$TMP/plan.json" '.units[]'
same_keys "require"  requirement     "$TMP/plan.json" '.units[].requires[]'
same_keys "preflight" preflight      "$TMP/plan.json" '.preflight'
same_keys "wire"     wireConventions "$TMP/plan.json" '.wire_conventions'

# The list itself, since a consumer reads the plan through it.
eq "units are listed by id" \
  "$(jq -r '[.units[].id] == ([.units[].id] | sort)' "$TMP/plan.json")" "true"
eq "and carry no lifecycle, which could only ever have read 'accepted'" \
  "$(jq -r '[.units[] | has("lifecycle")] | unique | join(",")' "$TMP/plan.json")" \
  "false"

# ─────────────────────────────────────────────────────────────────────────────
# The two sub-documents the canonical fixture is too healthy to produce
# ─────────────────────────────────────────────────────────────────────────────

plan_in pr-01-derive-refusal > "$TMP/findings.json"
same_keys "finding" finding "$TMP/findings.json" '.findings[]'

plan_in pr-12-empty-frontier > "$TMP/refused.json"
same_keys "refusal" refusal "$TMP/refused.json" '.'
eq "a refusal names no units" \
  "$(jq -r 'has("units")' "$TMP/refused.json")" "false"
eq "and its refused[] matches the schema" \
  "$(jq -r '.refused[0] | keys_unsorted | sort | join(",")' "$TMP/refused.json")" \
  "$(jq -r '.["$defs"].refusal.properties.refused.items.properties | keys_unsorted | sort | join(",")' "$JSON_SCHEMA")"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
