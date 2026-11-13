#!/usr/bin/env bash
# plugin/base/bin/test/test-heading-keys.sh — behavioural tests for `heading-keys.sh`
#
# Usage: bash plugin/base/bin/test/test-heading-keys.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
KEYS="$HERE/../heading-keys.sh"
source "$HERE/../_lib.sh"
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

template_ids() {
  local t
  for t in "$@"; do
    awk '
      /^## / { parent = "" }
      /^#{2,3} [A-Z]+[0-9]+: / {
        id = $2; sub(/:$/, "", id)
        name = $0; sub(/^#+ [A-Z]+[0-9]+: /, "", name)
        printf "%s\t%s\t%s\n", id, name, ($1 == "###" ? parent : "")
        if ($1 == "##") parent = name
      }
    ' "$SKILLS/$t"
  done | sort -u
}
for pair in \
  "action inspire-domain/templates/action.template.md" \
  "entity inspire-domain/templates/entity.template.md" \
  "feature inspire-feature/templates/feature.template.md" \
  "adr inspire-adr/templates/adr.template.md inspire-adr/templates/adr.rationale.template.md" \
  "screen inspire-screens/templates/screen.template.md" \
  "pattern inspire-screens/templates/pattern.template.md" \
  "component inspire-screens/templates/component.template.md" \
  "layout inspire-screens/templates/layout.template.md" \
  "module inspire-module/templates/module.template.md" \
  "spike inspire-spike/templates/spike.template.md"; do
  set -- $pair
  kind="$1"; shift
  want="$(template_ids "$@")"
  got="$(printf '%s\n' "$SDD_SECTION_IDS" | awk -F'\t' -v k="$kind" '$1 == k { print $2 "\t" $3 "\t" $4 }' | sort -u)"
  [ -n "$want" ] || bad "the $kind template carries no section id"
  eq "the $kind ids are the template's headings" "$got" "$want"
done

ROOT="$(mktemp -d -t inspire-heading-keys-test.XXXXXX)" || exit 1
trap 'rm -rf "$ROOT"' EXIT
export SDD_KB_ROOT="$ROOT/kb" SDD_SPEC_ROOT="$ROOT/kb/01_spec"
mkdir -p "$SDD_SPEC_ROOT/_modules/auth/_domain/user" "$SDD_SPEC_ROOT/_adr" "$SDD_SPEC_ROOT/_faces/app/_screens"

ENTITY="$SDD_SPEC_ROOT/_modules/auth/_domain/user/user.entity.md"
cat > "$ENTITY" <<'MD'
---
id: auth.user
lifecycle: draft
---

## Purpose
The user account. [pdd](../../pdd.md)

## ENT2: Justificación
Already keyed, so left alone.

## Invariants: Invariantes
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

ADR="$SDD_SPEC_ROOT/_adr/auth-sessions.adr.rationale.md"
printf '# T — rationale\n\n**Decision:** [adr-auth-sessions](auth-sessions.adr.md)\n\n## Context\nWhy.\n\n## Consequences\nWhat.\n\n### Breaking changes\n- None.\n\n## Alternatives considered\n### Breaking changes\nWrong parent.\n\n## Related ADRs\n- none\n' > "$ADR"
printf '# T\n\n**Status:** design\n**Rationale:** [adr-auth-sessions.rationale](auth-sessions.adr.rationale.md)\n\n## Decision\nDo it.\n' > "$SDD_SPEC_ROOT/_adr/auth-sessions.adr.md"

SCREEN="$SDD_SPEC_ROOT/_faces/app/_screens/login.screen.md"
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
has "the decision is rewritten"          "rewrote	$SDD_SPEC_ROOT/_adr/auth-sessions.adr.md	1" "$out"
has "the screen is rewritten"            "rewrote	$SCREEN	4" "$out"

E="$(cat "$ENTITY")"
has   "a bare name gains its id and keeps the name as label" "## ENT1: Purpose" "$E"
has   "a two-word name maps to its id"     "## ENT5: Touched by" "$E"
has   "a name with a label keeps the label" "## ENT3: Invariantes" "$E"
has   "an id heading is left alone"         "## ENT2: Justificación" "$E"
has   "an unknown heading stays as written" $'\n## Extra\n' "$(printf '\n%s\n' "$E")"
has   "a field H3 stays as written"         $'\n### id\n' "$(printf '\n%s\n' "$E")"
eq    "a commented and a fenced heading stay, the real one changes" \
      "$(grep -c '^## Fields$' "$ENTITY") $(grep -c '^## ENT4: Fields$' "$ENTITY")" "2 1"
has   "frontmatter is untouched"            $'---\nid: auth.user\nlifecycle: draft\n---' "$E"

A="$(cat "$ADR")"
has "Breaking changes under Consequences gains its id" $'## ADR3: Consequences\nWhat.\n\n### ADR4: Breaking changes' "$A"
has "Breaking changes under another parent stays"     $'## ADR5: Alternatives considered\n### Breaking changes\n' "$A"

S="$(cat "$SCREEN")"
has "a binding subsection gains its id"  "### SCR7: States" "$S"
has "a Render region keeps its name"      $'## SCR8: Render\n\n### States\n' "$S"

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
