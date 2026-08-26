#!/usr/bin/env bash
# plugin/base/bin/test/test-ratchet-update.sh — behavioural tests for
# `escape-hatch-ratchet.sh --update`.
#
# The golden fixture runner (run-tests.sh) is read-only by design: a fixture is
# a tree the rule scans, never one the rule rewrites. `--update` rewrites its
# own config — that is its entire point — so its defining guarantee ("a ceiling
# only ever moves DOWN") cannot live in a fixture and gets a behavioural script
# instead, wired into run-tests.sh explicitly like test-trust.sh.
#
# Every test builds its own scratch tree under mktemp -d; nothing in the repo
# is touched.
#
# Usage: bash plugin/base/bin/test/test-ratchet-update.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
RATCHET="$HERE/../escape-hatch-ratchet.sh"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

if [ ! -x "$RATCHET" ]; then
  echo "FAIL escape-hatch-ratchet.sh is not executable at $RATCHET" >&2
  echo ""; echo "Passed: 0 · Failed: 1"
  exit 1
fi

ROOT="$(mktemp -d -t inspire-ratchet-update-test.XXXXXX)" || exit 1
trap 'rm -rf "$ROOT"' EXIT

# One tree, three patterns, one of each kind:
#   slack   — count 1, ceiling 5  → --update must LOWER it to 1
#   at-cap  — count 2, ceiling 2  → --update must leave it at 2 (resting state)
#   breach  — count 2, ceiling 1  → --update must NOT raise it, and the run fails
mkdir -p "$ROOT/src"
cat > "$ROOT/src/a.ts" <<'EOF'
const a = SLACK_HATCH;
const b = ATCAP_HATCH; const c = ATCAP_HATCH;
const d = BREACH_HATCH; const e = BREACH_HATCH;
EOF
cat > "$ROOT/.escape-hatches.json" <<'EOF'
{
  "scope": ["src"],
  "extensions": ["ts"],
  "patterns": [
    { "id": "slack",  "regex": "SLACK_HATCH",  "ceiling": 5 },
    { "id": "at-cap", "regex": "ATCAP_HATCH",  "ceiling": 2 },
    { "id": "breach", "regex": "BREACH_HATCH", "ceiling": 1 }
  ]
}
EOF

( cd "$ROOT" && "$RATCHET" --update >/dev/null 2>&1 )
update_exit=$?

ceiling(){ jq -r --arg id "$1" '.patterns[] | select(.id == $id) | .ceiling' "$ROOT/.escape-hatches.json"; }

eq "update exits non-zero while a pattern is in breach"      "$update_exit" "1"
eq "a ceiling with slack is lowered to the measured count"   "$(ceiling slack)"  "1"
eq "a ceiling at its count is left untouched"                "$(ceiling at-cap)" "2"
eq "a breached ceiling is NEVER raised"                      "$(ceiling breach)" "1"

# Idempotence: a second --update on the lowered config changes nothing further.
before="$(cat "$ROOT/.escape-hatches.json")"
( cd "$ROOT" && "$RATCHET" --update >/dev/null 2>&1 )
eq "a second update is a no-op on already-lowered ceilings"  "$(cat "$ROOT/.escape-hatches.json")" "$before"

# Check mode never writes: run without --update on a config with slack and
# assert the file is byte-identical afterwards.
cat > "$ROOT/.escape-hatches.json" <<'EOF'
{
  "scope": ["src"],
  "extensions": ["ts"],
  "patterns": [
    { "id": "slack", "regex": "SLACK_HATCH", "ceiling": 5 }
  ]
}
EOF
before="$(cat "$ROOT/.escape-hatches.json")"
( cd "$ROOT" && "$RATCHET" >/dev/null 2>&1 )
eq "check mode leaves the config untouched"                  "$(cat "$ROOT/.escape-hatches.json")" "$before"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
