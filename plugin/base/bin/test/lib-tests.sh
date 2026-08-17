#!/usr/bin/env bash
# plugin/base/bin/test/lib-tests.sh — unit tests for the _lib.sh readers
#
# The golden fixture runner (run-tests.sh) exercises rule scripts end to end,
# which is the right shape for a rule and the wrong shape for a helper: a
# reader used by no rule yet is pinned by nothing, and a reader used by three
# rules is pinned only through whatever those three happen to ask it. This
# script asserts the readers directly, so their contracts survive the next
# rule that leans on them.
#
# Everything is built under one `mktemp -d` root: the inputs are small, and
# their point is the parse, not the path.
#
# Usage: bash plugin/base/bin/test/lib-tests.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
# shellcheck source=../_lib.sh
source "$HERE/../_lib.sh"

pass=0; fail=0
ok(){   echo "PASS $1"; pass=$((pass+1)); }
bad(){  echo "FAIL $1"; fail=$((fail+1)); }
eq(){   if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has(){  if printf '%s\n' "$3" | grep -q -- "$2"; then ok "$1"; else bad "$1 (no match for '$2')"; fi; }
hasnt(){ if printf '%s\n' "$3" | grep -q -- "$2"; then bad "$1 (unexpected match for '$2')"; else ok "$1"; fi; }
yes(){  if "${@:2}" >/dev/null 2>&1; then ok "$1"; else bad "$1 (expected exit 0)"; fi; }
no(){   if "${@:2}" >/dev/null 2>&1; then bad "$1 (expected non-zero exit)"; else ok "$1"; fi; }

ROOT="$(mktemp -d -t inspire-lib-test.XXXXXX)" || exit 1
trap 'rm -rf "$ROOT"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
# sdd_body_prose — what survives the reduction to prose
# ─────────────────────────────────────────────────────────────────────────────

cat > "$ROOT/prose.md" <<'EOF'
---
id: auth.user
lifecycle: draft
---

## Rationale
Grounded in [[adr-auth-01|adr-auth-01-sessions]] and [[adr-auth-02]].

| Field | Type |
|-------|------|
| `id`  | uuid |

---

Below a thematic break.

- a list item, which is not a thematic break
-- two dashes are not one either

````markdown
```
## Errors
```
still inside the outer fence
````

After the nested fence.

## Next
EOF

prose="$(sdd_body_prose "$ROOT/prose.md" "Rationale")"

has   "body_prose keeps prose"                  "Below a thematic break" "$prose"
has   "body_prose keeps list items"             "a list item"            "$prose"
has   "body_prose keeps two-dash lines"         '^-- two dashes'         "$prose"
has   "body_prose unwraps piped wikilinks"      "adr-auth-01-sessions"   "$prose"
hasnt "body_prose drops the wikilink brackets"  '\[\['                   "$prose"
has   "body_prose unwraps bare wikilinks"       "adr-auth-02"            "$prose"
hasnt "body_prose drops table rows"             "uuid"                   "$prose"
hasnt "body_prose drops fenced content"         "## Errors"              "$prose"
hasnt "body_prose drops nested-fence content"   "still inside"           "$prose"
has   "body_prose resumes after a nested fence" "After the nested fence" "$prose"
hasnt "body_prose stops at the next H2"         "## Next"                "$prose"
# The bare thematic break: structure, not prose.
hasnt "body_prose drops a bare thematic break"  '^---'                   "$prose"

cat > "$ROOT/break-only.md" <<'EOF'
## Rationale
   ----
EOF
eq "body_prose drops an indented, longer thematic break" \
   "$(sdd_body_prose "$ROOT/break-only.md" "Rationale" | tr -d '[:space:]')" ""

# ─────────────────────────────────────────────────────────────────────────────
# sdd_has_section / sdd_has_subsection / sdd_body_subsection
# ─────────────────────────────────────────────────────────────────────────────

cat > "$ROOT/sections.md" <<'EOF'
---
lifecycle: draft
---

## Consequences
What follows.

### Breaking changes
- the token format changes

### Other note
- unrelated

## Alternatives considered
### Breaking changes
- an H3 of the same name under the wrong parent

### Only under alternatives
- an H3 that exists in the file but never under Consequences

## Consequences
### Breaking changes
- a second parent must not concatenate onto the first
EOF

yes "has_section finds an H2"                sdd_has_section "$ROOT/sections.md" "Consequences"
no  "has_section rejects an absent H2"       sdd_has_section "$ROOT/sections.md" "Context"
yes "has_section level 3 finds an H3"        sdd_has_section "$ROOT/sections.md" "Breaking changes" 3
no  "has_section level 2 rejects an H3"      sdd_has_section "$ROOT/sections.md" "Breaking changes" 2
sdd_has_section "$ROOT/sections.md" "Consequences" 4 >/dev/null 2>&1
eq  "has_section rejects an unsupported level" "$?" "2"

yes "has_subsection finds the H3 under its parent" \
    sdd_has_subsection "$ROOT/sections.md" "Consequences" "Breaking changes"
# The parent EXISTS and precedes the H3 being looked for, so answering "no"
# requires the reader to have left the parent section at the next H2. A parent
# that is simply absent would never reach that branch and would pass whether or
# not the reset is there.
no  "has_subsection rejects an H3 that follows the parent's section" \
    sdd_has_subsection "$ROOT/sections.md" "Consequences" "Only under alternatives"
no  "has_subsection rejects an absent parent" \
    sdd_has_subsection "$ROOT/sections.md" "Context" "Breaking changes"

sub="$(sdd_body_subsection "$ROOT/sections.md" "Consequences" "Breaking changes")"
has   "body_subsection returns the H3 body"        "token format changes"  "$sub"
hasnt "body_subsection stops at the next H3"       "unrelated"             "$sub"
hasnt "body_subsection takes the FIRST match only" "second parent"         "$sub"

# ─────────────────────────────────────────────────────────────────────────────
# Fence tracking — the two CommonMark edges the rules depend on
#
# Both are asserted as CommonMark defines them, because that is what _lib.sh
# implements (sdd_fence: the 4-space indent guard and the backtick info-string
# guard). The control case below proves the assertion can fail: a genuine
# unclosed fence DOES swallow the header that follows it.
# ─────────────────────────────────────────────────────────────────────────────

printf '## A\n    ```\n\n## Errors\n- x\n'   > "$ROOT/fence-indented.md"
printf '## A\n```js`x\n\n## Errors\n- x\n'   > "$ROOT/fence-infotick.md"
printf '## A\n```\n\n## Errors\n- x\n'       > "$ROOT/fence-real.md"

yes "a 4-space-indented fence marker does not open a fence" \
    sdd_has_section "$ROOT/fence-indented.md" "Errors"
yes "a backtick in the info string does not open a fence" \
    sdd_has_section "$ROOT/fence-infotick.md" "Errors"
no  "control: a real unclosed fence does swallow the rest" \
    sdd_has_section "$ROOT/fence-real.md" "Errors"

# ─────────────────────────────────────────────────────────────────────────────
# KB layer discovery — the scope contract, by construction
# ─────────────────────────────────────────────────────────────────────────────

KB="$ROOT/kb"
mkdir -p "$KB/03_features/auth" "$KB/03_features/auth/nested" \
         "$KB/01_adr" "$KB/04_domain/auth/user" \
         "$KB/05_screens/auth" "$KB/05_screens/console/billing" \
         "$KB/05_screens/patterns" "$KB/05_screens/components"
: > "$KB/03_features/auth/FEAT-01-login.md"
: > "$KB/03_features/auth/_index.md"
: > "$KB/03_features/auth/README.md"
: > "$KB/03_features/README.md"
: > "$KB/03_features/auth/nested/too-deep.md"
: > "$KB/01_adr/adr-auth-sessions.md"
: > "$KB/01_adr/README.md"
: > "$KB/01_adr/_index.md"
: > "$KB/04_domain/auth/user/auth.user.md"
: > "$KB/05_screens/auth/login.md"
: > "$KB/05_screens/console/billing/invoices.md"
: > "$KB/05_screens/patterns/form.md"
: > "$KB/05_screens/components/table.md"
: > "$KB/05_screens/auth/_index.md"
: > "$KB/05_screens/auth/README.md"
: > "$KB/05_screens/design-system.md"

feats="$(sdd_find_features "$KB")"
has   "find_features finds a use-case file"        "FEAT-01-login.md" "$feats"
hasnt "find_features excludes _index.md"           "_index.md"        "$feats"
hasnt "find_features excludes README.md"           "README.md"        "$feats"
hasnt "find_features excludes deeper-than-module"  "too-deep.md"      "$feats"
hasnt "find_features ignores other layers"         "04_domain"        "$feats"

adrs="$(sdd_find_adrs "$KB")"
has   "find_adrs finds adr-*.md"                   "adr-auth-sessions.md" "$adrs"
hasnt "find_adrs excludes README/_index"           "index"                "$adrs"

screens="$(sdd_find_screens "$KB")"
has   "find_screens finds the flat shape"          "auth/login.md"      "$screens"
has   "find_screens finds the surface-first shape" "billing/invoices.md" "$screens"
hasnt "find_screens excludes patterns/"            "patterns/"          "$screens"
hasnt "find_screens excludes components/"          "components/"        "$screens"
hasnt "find_screens excludes _index.md"            "_index.md"          "$screens"
hasnt "find_screens excludes README.md"            "README.md"          "$screens"
hasnt "find_screens excludes top-level files"      "design-system.md"   "$screens"

# The intersection half of the contract: a domain-scoped run yields nothing
# from any of the three, and a layer-scoped run yields only that layer.
eq "find_features is empty on a domain scope" "$(sdd_find_features "$KB/04_domain")" ""
eq "find_adrs is empty on a domain scope"     "$(sdd_find_adrs     "$KB/04_domain")" ""
eq "find_screens is empty on a domain scope"  "$(sdd_find_screens  "$KB/04_domain")" ""
eq "find_features is empty on the ADR layer"  "$(sdd_find_features "$KB/01_adr")"    ""
has "find_features narrows to a module scope" "FEAT-01-login.md" \
    "$(sdd_find_features "$KB/03_features/auth")"

# ─────────────────────────────────────────────────────────────────────────────
# sdd_scope_intersect — the shared scope contract
#
# One helper answers "what should this layer scan" for the domain finders and
# for sections-present alike. Two things it must get right: the four cases, and
# the fact that a directory has many spellings.
# ─────────────────────────────────────────────────────────────────────────────

eq "scope_norm squeezes // runs"        "$(sdd_scope_norm 'a//b')"      "a/b"
eq "scope_norm strips leading ./"       "$(sdd_scope_norm './a/b')"     "a/b"
eq "scope_norm strips repeated ./"      "$(sdd_scope_norm './/./a/b')"  "a/b"
eq "scope_norm strips a trailing /"     "$(sdd_scope_norm 'a/b/')"      "a/b"
eq "scope_norm leaves a clean path be"  "$(sdd_scope_norm 'a/b')"       "a/b"
eq "scope_norm keeps an absolute path"  "$(sdd_scope_norm '/a//b/')"    "/a/b"

eq "intersect: empty scope means the whole layer" \
   "$(sdd_scope_intersect "" "kb/04_domain")" "kb/04_domain"
eq "intersect: scope inside the layer scans the scope" \
   "$(sdd_scope_intersect "kb/04_domain/auth" "kb/04_domain")" "kb/04_domain/auth"
eq "intersect: layer inside the scope scans the layer" \
   "$(sdd_scope_intersect "kb" "kb/04_domain")" "kb/04_domain"
eq "intersect: scope equal to the layer" \
   "$(sdd_scope_intersect "kb/04_domain" "kb/04_domain")" "kb/04_domain"
eq "intersect: disjoint scope yields nothing" \
   "$(sdd_scope_intersect "kb/03_features" "kb/04_domain")" ""
eq "intersect: a nonexistent scope stays silent" \
   "$(sdd_scope_intersect "no/such/place" "kb/04_domain")" ""

# Spelling independence. The first two are lexical; the third needs the
# physical comparison, since no amount of string work relates an absolute
# spelling to a relative one.
eq "intersect: a ./-prefixed scope behaves like the canonical one" \
   "$(sdd_scope_intersect "./kb/04_domain" "kb/04_domain")" "kb/04_domain"
eq "intersect: a //-carrying scope behaves like the canonical one" \
   "$(sdd_scope_intersect "kb//04_domain/" "kb/04_domain")" "kb/04_domain"
(
  cd "$ROOT" || exit 1
  abs_in="$(sdd_scope_intersect "$KB/04_domain/auth" "kb/04_domain")"
  abs_out="$(sdd_scope_intersect "$KB" "kb/04_domain")"
  printf '%s\n%s\n' "$abs_in" "$abs_out"
) > "$ROOT/abs.out"
eq "intersect: an absolute scope inside a relative layer" \
   "$(sed -n 1p "$ROOT/abs.out")" "$KB/04_domain/auth"
eq "intersect: an absolute scope containing a relative layer" \
   "$(sed -n 2p "$ROOT/abs.out")" "kb/04_domain"

# The gate-integrity case: a screen file that happens to carry a dotted
# basename is not a domain object, and a KB-wide scope must not make it one.
mkdir -p "$KB/04_domain/auth/user"
: > "$KB/05_screens/auth/user.profile.md"
: > "$KB/05_screens/auth/user.profile.edit.md"
: > "$KB/04_domain/auth/user/auth.user.md"
: > "$KB/04_domain/auth/user/auth.user.create.md"
(
  cd "$ROOT" || exit 1
  SDD_SPEC_ROOT="kb/04_domain"
  printf 'ENT %s\n' $(sdd_find_entities "kb")
  printf 'ACT %s\n' $(sdd_find_actions  "kb")
) > "$ROOT/shape.out"
has   "find_entities keeps its own layer's entity on a KB-wide scope" \
      "04_domain/auth/user/auth.user.md" "$(cat "$ROOT/shape.out")"
has   "find_actions keeps its own layer's action on a KB-wide scope" \
      "04_domain/auth/user/auth.user.create.md" "$(cat "$ROOT/shape.out")"
hasnt "find_entities ignores a dotted-basename screen file" \
      "user.profile.md" "$(cat "$ROOT/shape.out")"
hasnt "find_actions ignores a dotted-basename screen file" \
      "user.profile.edit.md" "$(cat "$ROOT/shape.out")"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
