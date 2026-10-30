#!/usr/bin/env bash
# plugin/base/bin/test/test-decisions.sh — behavioural tests for `decisions.sh`
#
# Usage: bash plugin/base/bin/test/test-decisions.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
DECISIONS="$HERE/../decisions.sh"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1"; diff <(printf '%s\n' "$3") <(printf '%s\n' "$2") | sed 's/^/    /'; fi; }
has(){ if printf '%s\n' "$3" | grep -qF -- "$2"; then ok "$1"; else bad "$1 (no match for '$2')"; fi; }
hasnt(){ if printf '%s\n' "$3" | grep -qF -- "$2"; then bad "$1 (unexpected match for '$2')"; else ok "$1"; fi; }

if [ ! -x "$DECISIONS" ]; then
  echo "FAIL decisions.sh is not executable at $DECISIONS" >&2
  echo ""; echo "Passed: 0 · Failed: 1"
  exit 1
fi

ROOT="$(mktemp -d -t inspire-decisions-test.XXXXXX)" || exit 1
trap 'rm -rf "$ROOT"' EXIT
export SDD_KB_ROOT="$ROOT/kb" SDD_SPEC_ROOT="$ROOT/kb/04_domain"
ADR="$SDD_KB_ROOT/01_adr"

out="$("$DECISIONS")"; rc=$?
eq "no ADR layer: nothing printed" "$out" ""
eq "and exit 0"                    "$rc"  "0"

mkdir -p "$ADR"
printf '# Old\n\n**Status:** superseded by [[adr-auth-sessions]]\n\n## Decision\nCookies.\n' \
  > "$ADR/adr-auth-cookies.md"
printf '# Gone\n\n**Status:** Rejected\n\n## Decision\nNothing.\n' > "$ADR/adr-gone.md"
eq "only superseded and rejected ADRs: nothing printed" "$("$DECISIONS")" ""

cat > "$ADR/adr-auth-sessions.md" <<'MD'
---
surfaces: [api, console]
endorsed:
  by: "@someone"
---

# Session tokens are opaque

**Status:** implemented
**Modules affected:** [[auth]]
**Rationale:** [[adr-auth-sessions.rationale]]
<!-- Status maturity ladder: design | prototyped | implemented -->

## Decision
Session tokens are opaque strings, minted server-side.
<!-- a guidance comment -->

No client parses a token.
MD
cat > "$ADR/adr-auth-sessions.rationale.md" <<'MD'
# Session tokens are opaque — rationale

**Decision:** [[adr-auth-sessions]]

## Context
The rationale never reaches the digest.
MD
cat > "$ADR/adr-action-verbs.md" <<'MD'
# Action verbs

**Status:** design

## Context
A single-file ADR: only its decision is read.

## Decision
- A book is reserved, cancelled and picked up.
- Every mutation emits an event.

## Consequences
Not in the digest.
MD
cat > "$ADR/adr-everywhere.md" <<'MD'
---
surfaces: all
---

# One clock

**Status:** prototyped
**Rationale:** [[adr-everywhere.rationale]]

## Decision
Every timestamp is UTC.
MD
printf '# No status\n\n## Decision\nUse it.\n' > "$ADR/adr-unlabelled.md"
printf '# README\n' > "$ADR/README.md"

cat > "$ROOT/full.txt" <<'EOF'
INSPIRE decisions — 4 live ADR(s) in `inspire_kb/01_adr/`. An ADR listing surfaces binds only those; one listing none binds the whole suite. Follow each one when you specify or build; to change one, use `/inspire-adr`. A `design` or `prototyped` decision can still be refined, an `implemented` one only superseded. The reasons are in each ADR's `.rationale.md`.

- **adr-action-verbs** (design) — Action verbs
  - A book is reserved, cancelled and picked up.
  - Every mutation emits an event.
- **adr-auth-sessions** (implemented; surfaces: api, console) — Session tokens are opaque
  Session tokens are opaque strings, minted server-side.

  No client parses a token.
- **adr-everywhere** (prototyped) — One clock
  Every timestamp is UTC.
- **adr-unlabelled** (no status) — No status
  Use it.
EOF
FULL="$(cat "$ROOT/full.txt")"
out="$("$DECISIONS")"; rc=$?
eq "the full digest" "$out" "$FULL"
eq "exits 0"         "$rc"  "0"

eq "a budget it fits under changes nothing" "$("$DECISIONS" --budget 100000)" "$FULL"

out="$("$DECISIONS" --surface web)"
has   "--surface keeps a suite-wide ADR"         "adr-action-verbs" "$out"
has   "--surface keeps an ADR listing all"       "adr-everywhere" "$out"
hasnt "--surface drops an ADR for other surfaces" "adr-auth-sessions" "$out"
has   "--surface names the surface in the head"  "3 live ADR(s) in \`inspire_kb/01_adr/\` that bind the \`web\` surface." "$out"
has   "--surface keeps an ADR listing it" "adr-auth-sessions" "$("$DECISIONS" --surface console)"

cat > "$ROOT/head.txt" <<'EOF'
INSPIRE decisions — 4 live ADR(s) in `inspire_kb/01_adr/`. An ADR listing surfaces binds only those; one listing none binds the whole suite. Follow each one when you specify or build; to change one, use `/inspire-adr`. A `design` or `prototyped` decision can still be refined, an `implemented` one only superseded. The reasons are in each ADR's `.rationale.md`.

Their full text is over this digest's budget: read an ADR before you specify or build in its area, or run `.inspire/bin/decisions.sh` for every decision.
EOF
HEAD_AND_TAIL="$(cat "$ROOT/head.txt")"
budget=$(( ${#HEAD_AND_TAIL} + 1 + 46 + 1 + 17 ))
eq "over budget: an index, cut with a count" "$("$DECISIONS" --budget "$budget")" "$HEAD_AND_TAIL

- **adr-action-verbs** (design) — Action verbs
- … and 3 more"
out="$("$DECISIONS" --budget "$budget")"
check_len=$(( ${#out} <= budget ))
eq "the index stays within the budget" "$check_len" "1"

eq "a budget that fits no entry: only the count" "$("$DECISIONS" --budget 10)" "$HEAD_AND_TAIL

- … 4 not listed"

"$DECISIONS" --budget many >/dev/null 2>&1; eq "a non-numeric budget exits 2" "$?" "2"
"$DECISIONS" --bogus >/dev/null 2>&1;       eq "an unknown argument exits 2"  "$?" "2"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
