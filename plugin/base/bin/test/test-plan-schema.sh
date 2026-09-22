#!/usr/bin/env bash
# plugin/base/bin/test/test-plan-schema.sh — that the three shipped schema
# artifacts still describe what `emanate-plan.sh` actually prints.
#
# `schemas/` carries one contract in three renderings: `emanation-plan.schema.json`
# is canonical, and the `.d.ts` and `.py` beside it exist so a TypeScript viewer
# and a Python orchestrator can consume the plan natively without either
# generating code at build time or taking a dependency. Three renderings of one
# truth drift, and a stale one is worse than none: it type-checks a consumer
# against a shape the emitter stopped producing.
#
# So this asserts the DIRECTION that actually breaks — emitter first, documents
# second. It runs the real script over real fixtures, walks the keys it emitted,
# and requires each to be declared in all three. A field added to the jq program
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
TS="$SCHEMAS/emanation-plan.d.ts"
PY="$SCHEMAS/emanation_plan.py"

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
  "inspire.emanation-plan/2"

same_keys "plan"     plan            "$TMP/plan.json" '.'
same_keys "wave"     wave            "$TMP/plan.json" '.waves[]'
same_keys "unit"     unit            "$TMP/plan.json" '.waves[].units[]'
same_keys "require"  requirement     "$TMP/plan.json" '.waves[].units[].requires[]'
same_keys "preflight" preflight      "$TMP/plan.json" '.preflight'
same_keys "wire"     wireConventions "$TMP/plan.json" '.wire_conventions'

# The nesting itself, since a consumer reads the plan through it.
eq "waves carry a 1-based contiguous numbering" \
  "$(jq -r '[.waves[].wave] | join(",")' "$TMP/plan.json")" "1,2,3"
eq "floor is the number of waves" \
  "$(jq -r '.floor == (.waves | length)' "$TMP/plan.json")" "true"
eq "a unit carries no wave back-pointer: the nesting is the index" \
  "$(jq -r '[.waves[].units[] | has("wave")] | unique | join(",")' "$TMP/plan.json")" \
  "false"
eq "and no lifecycle, which could only ever have read 'accepted'" \
  "$(jq -r '[.waves[].units[] | has("lifecycle")] | unique | join(",")' "$TMP/plan.json")" \
  "false"

# ─────────────────────────────────────────────────────────────────────────────
# The two sub-documents the canonical fixture is too healthy to produce
# ─────────────────────────────────────────────────────────────────────────────

plan_in pr-01-derive-refusal > "$TMP/findings.json"
same_keys "finding" finding "$TMP/findings.json" '.findings[]'

plan_in pr-12-empty-frontier > "$TMP/refused.json"
same_keys "refusal" refusal "$TMP/refused.json" '.'
eq "a refusal names no wave and no floor" \
  "$(jq -r '[has("waves"), has("floor")] | join(",")' "$TMP/refused.json")" \
  "false,false"
eq "and its refused[] matches the schema" \
  "$(jq -r '.refused[0] | keys_unsorted | sort | join(",")' "$TMP/refused.json")" \
  "$(jq -r '.["$defs"].refusal.properties.refused.items.properties | keys_unsorted | sort | join(",")' "$JSON_SCHEMA")"

# ─────────────────────────────────────────────────────────────────────────────
# The two generated-language renderings name every key the emitter prints
# ─────────────────────────────────────────────────────────────────────────────

jq -r '[paths(scalars) as $p | $p[-1] | select(type == "string")] | unique[]' \
  "$TMP/plan.json" | LC_ALL=C sort -u > "$TMP/keys"

for rendering in "$TS" "$PY"; do
  missing=""
  while IFS= read -r key; do
    LC_ALL=C grep -q "[^A-Za-z_]${key}[^A-Za-z_]" "$rendering" \
      || missing="$missing $key"
  done < "$TMP/keys"
  eq "$(basename "$rendering") names every key the plan prints" "${missing# }" ""
done

# The schema id is one string in four places, and a bump that misses one turns a
# consumer's version check into a lie.
eq "every rendering carries the same schema id" \
  "$(for f in "$JSON_SCHEMA" "$TS" "$PY"; do
       LC_ALL=C grep -c 'inspire\.emanation-plan/2' "$f" | tr -d ' '
     done | LC_ALL=C sort -u | LC_ALL=C grep -c '^0$')" "0"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
