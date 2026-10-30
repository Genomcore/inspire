#!/usr/bin/env bash
# plugin/base/bin/test/test-adr-split.sh — behavioural tests for `adr-split.sh`
#
# Usage: bash plugin/base/bin/test/test-adr-split.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
SPLIT="$HERE/../adr-split.sh"
SECTIONS="$HERE/../sections-present.sh"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has(){ if printf '%s\n' "$3" | grep -qF -- "$2"; then ok "$1"; else bad "$1 (no match for '$2')"; fi; }
hasnt(){ if printf '%s\n' "$3" | grep -qF -- "$2"; then bad "$1 (unexpected match for '$2')"; else ok "$1"; fi; }

if [ ! -x "$SPLIT" ]; then
  echo "FAIL adr-split.sh is not executable at $SPLIT" >&2
  echo ""; echo "Passed: 0 · Failed: 1"
  exit 1
fi

ROOT="$(mktemp -d -t inspire-adr-split-test.XXXXXX)" || exit 1
trap 'rm -rf "$ROOT"' EXIT
export SDD_KB_ROOT="$ROOT/kb" SDD_SPEC_ROOT="$ROOT/kb/04_domain"
ADR="$SDD_KB_ROOT/01_adr"
mkdir -p "$ADR"

cat > "$ADR/adr-auth-sessions.md" <<'MD'
---
surfaces: [console]
---

# Session tokens are opaque

**Status:** implemented
**Modules affected:** [[auth]]
<!--
## Decision is named here on purpose: a comment is not a section.
-->

## Context
Sessions need a transport-safe identifier.

```md
## Decision
A fenced heading is sample text.
```

## Decision
Session tokens are opaque strings, minted server-side.

## Consequences
Clients cannot introspect a token.

### Breaking changes
- None.

## Alternatives considered
1. **Signed JWTs.** Rejected: revocation is harder.

## Related ADRs
- [[adr-auth-password-hashing]] — sibling decision.

## Notes
An extra section travels with the rationale.
MD
printf '# No decision yet\n\n**Status:** design\n\n## Context\nOpen.\n' > "$ADR/adr-open.md"
printf '# README\n' > "$ADR/README.md"
ORIGINAL="$(cat "$ADR/adr-auth-sessions.md")"

listed="$("$SPLIT" --list)"; rc=$?
eq    "--list exits 0"                          "$rc" "0"
has   "--list names a single-file ADR"          "adr-auth-sessions.md" "$listed"
hasnt "--list ignores the README"               "README.md" "$listed"
eq    "--list writes nothing"                   "$(ls "$ADR" | wc -l | tr -d ' ')" "3"

out="$("$SPLIT")"; rc=$?
eq    "a file it cannot split makes the run exit 1" "$rc" "1"
has   "the split is reported"                   "split	$ADR/adr-auth-sessions.md	$ADR/adr-auth-sessions.rationale.md" "$out"
has   "an ADR with no ## Decision is skipped"   "skipped	$ADR/adr-open.md" "$out"
eq    "the skipped ADR is left untouched"       "$(cat "$ADR/adr-open.md")" "$(printf '# No decision yet\n\n**Status:** design\n\n## Context\nOpen.')"

DEC="$(cat "$ADR/adr-auth-sessions.md")"
RAT="$(cat "$ADR/adr-auth-sessions.rationale.md")"
eq "the decision keeps its frontmatter, header and ## Decision" "$DEC" "$(cat <<'MD'
---
surfaces: [console]
---

# Session tokens are opaque

**Status:** implemented
**Modules affected:** [[auth]]
**Rationale:** [[adr-auth-sessions.rationale]]
<!--
## Decision is named here on purpose: a comment is not a section.
-->

## Decision
Session tokens are opaque strings, minted server-side.
MD
)"
eq "the rationale takes every other section, in order" "$RAT" "$(cat <<'MD'
# Session tokens are opaque — rationale

**Decision:** [[adr-auth-sessions]]

## Context
Sessions need a transport-safe identifier.

```md
## Decision
A fenced heading is sample text.
```

## Consequences
Clients cannot introspect a token.

### Breaking changes
- None.

## Alternatives considered
1. **Signed JWTs.** Rejected: revocation is harder.

## Related ADRs
- [[adr-auth-password-hashing]] — sibling decision.

## Notes
An extra section travels with the rationale.
MD
)"

moved="$(printf '%s\n%s\n' "$DEC" "$RAT" \
  | grep -vxF '**Rationale:** [[adr-auth-sessions.rationale]]' \
  | grep -vxF '# Session tokens are opaque — rationale' \
  | grep -vxF '**Decision:** [[adr-auth-sessions]]' | grep -v '^$' | sort)"
eq "no line is lost or reworded" "$moved" "$(printf '%s\n' "$ORIGINAL" | grep -v '^$' | sort)"

findings="$("$SECTIONS" "$SDD_KB_ROOT" 2>&1 >/dev/null)"
hasnt "the split pair passes sections-present" "adr-auth-sessions" "$findings"

again="$("$SPLIT" "$ADR/adr-auth-sessions.md")"; rc=$?
eq "a second run on a split ADR does nothing" "$again" ""
eq "and exits 0"                              "$rc" "0"
eq "and leaves the decision as it was"        "$(cat "$ADR/adr-auth-sessions.md")" "$DEC"

printf '# Bare\n\n## Decision\nUse it.\n\n## Context\nWhy.\n' > "$ADR/adr-bare.md"
"$SPLIT" "$ADR/adr-bare.md" >/dev/null
eq "with no header lines, the link goes under the H1" "$(cat "$ADR/adr-bare.md")" \
  "$(printf '# Bare\n\n**Rationale:** [[adr-bare.rationale]]\n\n## Decision\nUse it.')"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
