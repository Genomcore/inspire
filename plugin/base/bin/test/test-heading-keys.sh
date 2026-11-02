#!/usr/bin/env bash
# plugin/base/bin/test/test-heading-keys.sh — behavioural tests for `heading-keys.sh`
#
# Usage: bash plugin/base/bin/test/test-heading-keys.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
KEYS="$HERE/../heading-keys.sh"
SECTIONS="$HERE/../sections-present.sh"
SKILLS="$HERE/../../skills"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has(){ if printf '%s\n' "$3" | grep -qF -- "$2"; then ok "$1"; else bad "$1 (no match for '$2')"; fi; }
hasnt(){ if printf '%s\n' "$3" | grep -qF -- "$2"; then bad "$1 (unexpected match for '$2')"; else ok "$1"; fi; }

if [ ! -x "$KEYS" ]; then
  echo "FAIL heading-keys.sh is not executable at $KEYS" >&2
  echo ""; echo "Passed: 0 · Failed: 1"
  exit 1
fi

template_keys() {
  local kind="$1" t
  shift
  for t in "$@"; do
    grep -E '^#{2,3} ([^:]+): \1$' "$SKILLS/$t" | sed -E 's/^(#+ [^:]+): .*/\1/' \
      | awk -v k="$kind" '{ print k "\t" $0 }'
  done | sort -u
}
for pair in \
  "action inspire-domain/templates/action.md.template" \
  "entity inspire-domain/templates/entity.md.template" \
  "feature inspire-feature/templates/use-case.md.template" \
  "adr inspire-adr/templates/adr.md.template inspire-adr/templates/adr.rationale.md.template" \
  "screen inspire-screens/templates/screen.md.template" \
  "pattern inspire-screens/templates/pattern-entry.md.template" \
  "component inspire-screens/templates/component-entry.md.template" \
  "layout inspire-screens/templates/layout-entry.md.template" \
  "module inspire-module/templates/module-hub.md.template" \
  "spike inspire-spike/templates/spike.md.template"; do
  set -- $pair
  kind="$1"; shift
  want="$(IFS=' '; template_keys "$kind" "$@")"
  got="$("$KEYS" --keys | awk -F'\t' -v k="$kind" '$1 == k' | sort -u)"
  eq "the $kind keys are the template's headings" "$got" "$want"
done

ROOT="$(mktemp -d -t inspire-heading-keys-test.XXXXXX)" || exit 1
trap 'rm -rf "$ROOT"' EXIT
export SDD_KB_ROOT="$ROOT/kb" SDD_SPEC_ROOT="$ROOT/kb/04_domain"
mkdir -p "$SDD_SPEC_ROOT/auth/user" "$SDD_KB_ROOT/01_adr" "$SDD_KB_ROOT/05_screens/auth"

ENTITY="$SDD_SPEC_ROOT/auth/user/auth.user.md"
cat > "$ENTITY" <<'MD'
---
id: auth.user
lifecycle: draft
---

## Purpose
The user account. [[pdd|pdd]]

## Rationale: Justificación
Already keyed, so left alone.

## Invariants
None beyond Fields constraints.

<!--
## Fields
A heading quoted in a comment is not a heading.
-->

```md
## Fields
A fenced heading is sample text.
```

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |

### id
Constraints: `nonnull, unique, immutable`

## Extra
An unknown heading stays as written.

## Touched by
MD

ADR="$SDD_KB_ROOT/01_adr/adr-auth-sessions.rationale.md"
printf '# T — rationale\n\n**Decision:** [[adr-auth-sessions]]\n\n## Context\nWhy.\n\n## Consequences\nWhat.\n\n### Breaking changes\n- None.\n\n## Alternatives considered\n### Breaking changes\nWrong parent.\n\n## Related ADRs\n- none\n' > "$ADR"
printf '# T\n\n**Status:** design\n**Rationale:** [[adr-auth-sessions.rationale]]\n\n## Decision\nDo it.\n' > "$SDD_KB_ROOT/01_adr/adr-auth-sessions.md"

SCREEN="$SDD_KB_ROOT/05_screens/auth/login.md"
printf '# Sign in\n\n**Features:** FEAT-01\n\n## Purpose\nSign in.\n\n## Bindings\n\n### States\n\n| Key | When | Presentation |\n|---|---|---|\n| `x` | y | z |\n\n## Render\n\n### States\nA region that happens to share a binding name.\n' > "$SCREEN"

BEFORE="$(cat "$ENTITY" "$ADR" "$SCREEN")"

listed="$("$KEYS" --list)"; rc=$?
eq  "--list exits 0"                     "$rc" "0"
has "--list counts the entity"           "$ENTITY	4" "$listed"
has "--list counts the rationale"        "$ADR	5" "$listed"
eq  "--list writes nothing"              "$(cat "$ENTITY" "$ADR" "$SCREEN")" "$BEFORE"

out="$("$KEYS")"; rc=$?
eq  "a rewrite exits 0"                  "$rc" "0"
has "the rewrite is reported"            "rewrote	$ENTITY	4" "$out"
has "the decision is rewritten"          "rewrote	$SDD_KB_ROOT/01_adr/adr-auth-sessions.md	1" "$out"
has "the screen is rewritten"            "rewrote	$SCREEN	4" "$out"

E="$(cat "$ENTITY")"
has   "a bare key gains its English label"  "## Purpose: Purpose" "$E"
has   "a two-word key keeps its spacing"    "## Touched by: Touched by" "$E"
has   "a keyed heading is left alone"       "## Rationale: Justificación" "$E"
hasnt "a translated label is not doubled"   "Rationale: Rationale" "$E"
has   "an unknown heading stays as written" $'\n## Extra\n' "$(printf '\n%s\n' "$E")"
has   "a field H3 stays as written"         $'\n### id\n' "$(printf '\n%s\n' "$E")"
eq    "a commented and a fenced heading stay, the real one changes" \
      "$(grep -c '^## Fields$' "$ENTITY") $(grep -c '^## Fields: Fields$' "$ENTITY")" "2 1"
has   "frontmatter is untouched"            $'---\nid: auth.user\nlifecycle: draft\n---' "$E"

A="$(cat "$ADR")"
has "Breaking changes under Consequences gains its label" $'## Consequences: Consequences\nWhat.\n\n### Breaking changes: Breaking changes' "$A"
has "Breaking changes under another parent stays"         $'## Alternatives considered: Alternatives considered\n### Breaking changes\n' "$A"

S="$(cat "$SCREEN")"
has "a binding subsection gains its label" "### States: States" "$S"
has "a Render region keeps its name"       $'## Render: Render\n\n### States\n' "$S"

findings="$("$SECTIONS" "$SDD_KB_ROOT" 2>&1 >/dev/null)"
hasnt "the rewritten KB passes sections-present" "missing required" "$findings"

AFTER="$(cat "$ENTITY" "$ADR" "$SCREEN")"
again="$("$KEYS")"; rc=$?
eq "a second run does nothing"       "$again" ""
eq "and exits 0"                     "$rc" "0"
eq "and leaves every file as it was" "$(cat "$ENTITY" "$ADR" "$SCREEN")" "$AFTER"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
