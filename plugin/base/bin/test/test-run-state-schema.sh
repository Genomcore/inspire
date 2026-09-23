#!/usr/bin/env bash
# The run-state writer and three shipped contract renderings agree on their keys.
set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
BIN="$HERE/.."
SCHEMAS="$BIN/schemas"
SOURCE="$HERE/fixtures/emanate-plan/clean-three-waves/expected-stdout.json"
TMP="$(mktemp -d -t inspire-run-state.XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

jq empty "$SCHEMAS/emanation-run-state.schema.json" || exit 1
python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text())' "$SCHEMAS/emanation_run_state.py" || exit 1
python3 "$BIN/emanate-run-state.py" init "$SOURCE" "$TMP/state.json" || exit 1
unit_id="$(jq -r '.waves[0].units[0].id' "$SOURCE")"
other_id="$(jq -r '.waves[0].units[1].id' "$SOURCE")"
python3 "$BIN/emanate-run-state.py" update "$SOURCE" "$TMP/state.json" \
  --unit "$unit_id" --status blocked --reason 'waiting for prerequisite' \
  --blocked-by "$other_id" --phase prepare --persona contracter \
  --integration-branch emanate/example --worktree .claude/worktrees/example \
  --rework-cycles 1 --infrastructure-retries 1 || exit 1

root_emitted="$(jq -r 'keys | sort | join(",")' "$TMP/state.json")"
root_schema="$(jq -r '.properties | keys | sort | join(",")' "$SCHEMAS/emanation-run-state.schema.json")"
eq "root fields match the JSON Schema" "$root_emitted" "$root_schema"
unit_emitted="$(jq -r --arg id "$unit_id" '.units[$id] | keys | sort | join(",")' "$TMP/state.json")"
unit_schema="$(jq -r '.["$defs"].unitState.properties | keys | sort | join(",")' "$SCHEMAS/emanation-run-state.schema.json")"
eq "unit fields match the JSON Schema" "$unit_emitted" "$unit_schema"
eq "unit map matches the plan" "$(jq -r '.units | length' "$TMP/state.json")" "$(jq -r '[.waves[].units[]] | length' "$SOURCE")"
python3 "$BIN/emanate-run-state.py" update "$SOURCE" "$TMP/state.json" --unit "$unit_id" --status running --phase persona --retry || exit 1
eq "a new attempt increments the counter" "$(jq -r --arg id "$unit_id" '.units[$id].attempt' "$TMP/state.json")" "1"
eq "retry clears the old block reason" "$(jq -r --arg id "$unit_id" '.units[$id] | has("reason")' "$TMP/state.json")" "false"
python3 "$BIN/emanate-run-state.py" update "$SOURCE" "$TMP/state.json" --unit "$unit_id" --status running --retry || exit 1
eq "an interrupted phase can start another attempt" "$(jq -r --arg id "$unit_id" '.units[$id].attempt' "$TMP/state.json")" "2"

for rendering in "$SCHEMAS/emanation-run-state.d.ts" "$SCHEMAS/emanation_run_state.py"; do
  missing=""
  for key in $(jq -r '(.properties | keys[]) , (.["$defs"].unitState.properties | keys[])' "$SCHEMAS/emanation-run-state.schema.json"); do
    LC_ALL=C grep -q "[^A-Za-z_]${key}[^A-Za-z_]" "$rendering" || missing="$missing $key"
  done
  eq "$(basename "$rendering") names every field" "${missing# }" ""
  eq "$(basename "$rendering") carries the schema id" "$(grep -c 'inspire.emanation-run-state/1' "$rendering" | tr -d ' ' | awk '{print ($1 > 0)}')" "1"
done

cp "$TMP/state.json" "$TMP/invalid.json"
jq --arg id "$unit_id" '.units[$id].status = "unknown"' "$TMP/invalid.json" > "$TMP/changed.json"
mv "$TMP/changed.json" "$TMP/invalid.json"
python3 "$BIN/viewer/serve.py" --check "$SOURCE" --run-state "$TMP/invalid.json" > /dev/null 2> "$TMP/error"
if [ "$?" -ne 0 ] && grep -q 'invalid status' "$TMP/error"; then ok "invalid unit state is rejected"; else bad "invalid unit state is rejected"; fi

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
