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
# Section ids — `## {ID}: {label}` or the legacy name, looked up by section name
# ─────────────────────────────────────────────────────────────────────────────

cat > "$ROOT/keyed.md" <<'EOF'
## ENT4: Campos
| Field | Type |

## Touched by:
modificada

## ADR3: Consecuencias
### ADR4: Cambios incompatibles
- el formato del token cambia

## Fieldset
not the Fields section

## ENT99: Unknown id
an id in no table names no section

## Errors:sin espacio
EOF

yes "has_section finds a section by its id"        sdd_has_section "$ROOT/keyed.md" "Fields"
no  "has_section never matches the label"          sdd_has_section "$ROOT/keyed.md" "Campos"
yes "has_section reads a legacy name, bare colon"  sdd_has_section "$ROOT/keyed.md" "Touched by"
no  "has_section never matches a name's prefix"    sdd_has_section "$ROOT/keyed.md" "Field"
no  "has_section needs a space after the colon"    sdd_has_section "$ROOT/keyed.md" "Errors"
yes "has_section matches an unknown id literally"  sdd_has_section "$ROOT/keyed.md" "ENT99"
yes "has_subsection finds id parent and id child" \
    sdd_has_subsection "$ROOT/keyed.md" "Consequences" "Breaking changes"
has   "body_section returns an id section's body"   "Field | Type" \
      "$(sdd_body_section "$ROOT/keyed.md" "Fields")"
hasnt "body_section stops at the next H2"           "modificada" \
      "$(sdd_body_section "$ROOT/keyed.md" "Fields")"
has   "body_subsection reads under id headings"     "el formato" \
      "$(sdd_body_subsection "$ROOT/keyed.md" "Consequences" "Breaking changes")"

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
SPEC="$KB/01_spec"
SDD_SPEC_ROOT="$SPEC"
M="$SPEC/_modules/auth"
mkdir -p "$M/_features/nested" "$M/_domain/user" "$M/_adr" "$SPEC/_adr" \
         "$SPEC/_faces/app/_screens" "$SPEC/_faces/console/_screens" \
         "$SPEC/_design-system/patterns" "$SPEC/_design-system/components" \
         "$SPEC/_bundles" "$SPEC/_processes" "$KB/00_bootstrap"
: > "$M/auth.module.md"
: > "$M/_features/FEAT-01-login.feature.md"
: > "$M/_features/feature.template.md"
: > "$M/_features/_index.md"
: > "$M/_features/README.md"
: > "$M/_features/nested/FEAT-02-deep.feature.md"
: > "$SPEC/_adr/auth-sessions.adr.md"
: > "$SPEC/_adr/auth-sessions.adr.rationale.md"
: > "$SPEC/_adr/README.md"
: > "$SPEC/_adr/adr.template.md"
: > "$M/_adr/auth-local.adr.md"
: > "$M/_domain/user/user.entity.md"
: > "$SPEC/_faces/app/app.face.md"
: > "$SPEC/_faces/app/_screens/login.screen.md"
: > "$SPEC/_faces/app/_index.md"
: > "$SPEC/_faces/console/_screens/invoices.screen.md"
: > "$SPEC/_design-system/patterns/form.pattern.md"
: > "$SPEC/_design-system/patterns/pattern.template.md"
: > "$SPEC/_design-system/patterns/README.md"
: > "$SPEC/_design-system/components/table.component.md"
: > "$SPEC/_design-system/design-system.md"
: > "$SPEC/_bundles/api.bundle.md"
: > "$SPEC/_processes/nightly.process.md"
: > "$KB/00_bootstrap/stack.md"

feats="$(sdd_find_features "$KB")"
has   "find_features finds a use-case file"        "FEAT-01-login.feature.md" "$feats"
has   "find_features finds one at any depth"       "FEAT-02-deep.feature.md"  "$feats"
hasnt "find_features excludes its template"        "template"         "$feats"
hasnt "find_features excludes _index.md"           "_index.md"        "$feats"
hasnt "find_features excludes README.md"           "README.md"        "$feats"
hasnt "find_features ignores other types"          "entity"           "$feats"

adrs="$(sdd_find_adrs "$KB")"
has   "find_adrs finds a global {slug}.adr.md"     "_adr/auth-sessions.adr.md" "$adrs"
has   "find_adrs finds a module-scoped one"        "auth-local.adr.md"         "$adrs"
hasnt "find_adrs excludes README and template"     "README\|template"          "$adrs"
hasnt "find_adrs excludes rationale files"         "rationale"                 "$adrs"

rats="$(sdd_find_adr_rationales "$KB")"
eq    "find_adr_rationales finds only the rationale" "${rats##*/}" "auth-sessions.adr.rationale.md"
eq    "find_adr_rationales is empty on a domain scope" "$(sdd_find_adr_rationales "$M/_domain")" ""

screens="$(sdd_find_screens "$KB")"
has   "find_screens finds a screen in one face"     "app/_screens/login.screen.md"        "$screens"
has   "find_screens finds a screen in another face" "console/_screens/invoices.screen.md" "$screens"
hasnt "find_screens excludes patterns"              "pattern"            "$screens"
hasnt "find_screens excludes the face's _index.md"  "_index.md"          "$screens"
hasnt "find_screens excludes the face file"         "app.face.md"        "$screens"
hasnt "find_screens excludes the design system"     "design-system.md"   "$screens"

eq "find_modules finds the module hub" "$(sdd_find_modules "$KB")" "$M/auth.module.md"
eq "find_bundles finds the bundle"     "$(sdd_find_bundles "$KB")" "$SPEC/_bundles/api.bundle.md"
eq "find_faces finds the face"         "$(sdd_find_faces "$KB")"   "$SPEC/_faces/app/app.face.md"
eq "find_processes finds the process"  "$(sdd_find_processes "$KB")" "$SPEC/_processes/nightly.process.md"

# The intersection half of the contract: a scope narrows every finder, and a scope
# outside the spec root yields nothing at all.
eq "find_features is empty on a domain scope" "$(sdd_find_features "$M/_domain")" ""
eq "find_adrs is empty on a domain scope"     "$(sdd_find_adrs     "$M/_domain")" ""
eq "find_screens is empty on a module scope"  "$(sdd_find_screens  "$M")"         ""
eq "find_features is empty on 00_bootstrap"   "$(sdd_find_features "$KB/00_bootstrap")" ""
eq "find_entities is empty on 00_bootstrap"   "$(sdd_find_entities "$KB/00_bootstrap")" ""
has "find_features narrows to a module scope" "FEAT-01-login.feature.md" \
    "$(sdd_find_features "$M")"
eq "find_screens narrows to one face" "$(sdd_find_screens "$SPEC/_faces/console")" \
   "$SPEC/_faces/console/_screens/invoices.screen.md"

# The catalog finder: one extension per catalog, wherever the entry sits.
pats="$(sdd_find_catalog "$KB" patterns)"
comps="$(sdd_find_catalog "$KB" components)"
has   "find_patterns finds a pattern entry"        "form.pattern.md"   "$pats"
hasnt "find_patterns excludes its template"        "template"          "$pats"
hasnt "find_patterns excludes README.md"           "README.md"         "$pats"
hasnt "find_patterns excludes the component catalog" "component"       "$pats"
hasnt "find_patterns excludes screens"             "screen"            "$pats"
has   "find_components finds a component entry"    "table.component.md" "$comps"
hasnt "find_components excludes the pattern catalog" "pattern"         "$comps"
eq "find_patterns is empty on a domain scope"   "$(sdd_find_catalog "$M/_domain" patterns)" ""
eq "resolve_catalog finds an entry by its id"   "$(sdd_resolve_catalog pattern form)" "$SPEC/_design-system/patterns/form.pattern.md"
eq "resolve_catalog reads a path-shaped target" "$(sdd_resolve_catalog patterns ../patterns/form)" "$SPEC/_design-system/patterns/form.pattern.md"
eq "resolve_catalog is empty for no such entry" "$(sdd_resolve_catalog pattern nothing)" ""

# The id a file is linked by: frontmatter first, then the name without its type.
printf -- '---\nid: auth::user\n---\n' > "$M/_domain/user/user.entity.md"
eq "artifact_id: the frontmatter id wins"        "$(sdd_artifact_id "$M/_domain/user/user.entity.md")" "auth::user"
eq "artifact_id: a catalog id has no extension"  "$(sdd_artifact_id "$SPEC/_design-system/patterns/form.pattern.md")" "form"
eq "artifact_id: an ADR adds back its prefix"    "$(sdd_artifact_id "$SPEC/_adr/auth-sessions.adr.md")" "adr-auth-sessions"
eq "artifact_id: and so does its rationale"      "$(sdd_artifact_id "$SPEC/_adr/auth-sessions.adr.rationale.md")" "adr-auth-sessions.rationale"
eq "artifact_id: a feature is its use case"      "$(sdd_artifact_id "$M/_features/FEAT-01-login.feature.md")" "FEAT-01-login"
eq "typed_kind: reads the extension"             "$(sdd_typed_kind "$SPEC/_bundles/api.bundle.md")" "bundle"
eq "typed_kind: a template has none"             "$(sdd_typed_kind "$SPEC/_adr/adr.template.md")" ""
eq "resolve_entity_id: by id, either form"       "$(sdd_resolve_entity_id auth.user)" "$M/_domain/user/user.entity.md"

# `**State:**` is a catalog entry's lifecycle line.
CAT="$SPEC/_design-system/components"
printf '# Component: a\n\n**State:** to-extract\n' > "$CAT/a.md"
printf '# Component: b\n\n**State:** implemented\n' > "$CAT/b.md"
printf '# Component: c\n\n**State:** planned\n'     > "$CAT/c.md"
printf '# Component: d\n\nno state line at all\n'   > "$CAT/d.md"
eq "catalog_state reads the line"            "$(sdd_catalog_state "$CAT/a.md")" "to-extract"
eq "catalog_state is empty when absent"      "$(sdd_catalog_state "$CAT/d.md")" ""
eq "catalog_state reads any word as written" "$(sdd_catalog_state "$CAT/c.md")" "planned"

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
   "$(sdd_scope_intersect "" "kb/01_spec")" "kb/01_spec"
eq "intersect: scope inside the layer scans the scope" \
   "$(sdd_scope_intersect "kb/01_spec/_modules" "kb/01_spec")" "kb/01_spec/_modules"
eq "intersect: layer inside the scope scans the layer" \
   "$(sdd_scope_intersect "kb" "kb/01_spec")" "kb/01_spec"
eq "intersect: scope equal to the layer" \
   "$(sdd_scope_intersect "kb/01_spec" "kb/01_spec")" "kb/01_spec"
eq "intersect: disjoint scope yields nothing" \
   "$(sdd_scope_intersect "kb/00_bootstrap" "kb/01_spec")" ""
eq "intersect: a nonexistent scope stays silent" \
   "$(sdd_scope_intersect "no/such/place" "kb/01_spec")" ""

# Spelling independence. The first two are lexical; the third needs the
# physical comparison, since no amount of string work relates an absolute
# spelling to a relative one.
eq "intersect: a ./-prefixed scope behaves like the canonical one" \
   "$(sdd_scope_intersect "./kb/01_spec" "kb/01_spec")" "kb/01_spec"
eq "intersect: a //-carrying scope behaves like the canonical one" \
   "$(sdd_scope_intersect "kb//01_spec/" "kb/01_spec")" "kb/01_spec"
(
  cd "$ROOT" || exit 1
  abs_in="$(sdd_scope_intersect "$KB/01_spec/_modules" "kb/01_spec")"
  abs_out="$(sdd_scope_intersect "$KB" "kb/01_spec")"
  printf '%s\n%s\n' "$abs_in" "$abs_out"
) > "$ROOT/abs.out"
eq "intersect: an absolute scope inside a relative layer" \
   "$(sed -n 1p "$ROOT/abs.out")" "$KB/01_spec/_modules"
eq "intersect: an absolute scope containing a relative layer" \
   "$(sed -n 2p "$ROOT/abs.out")" "kb/01_spec"

# The gate-integrity case: a screen whose slug happens to look like a domain id is
# not a domain object. The extension decides, never the shape of the name.
: > "$SPEC/_faces/app/_screens/user.profile.screen.md"
: > "$SPEC/_faces/app/_screens/user.profile.edit.screen.md"
: > "$M/_domain/user/user.create.action.md"
(
  cd "$ROOT" || exit 1
  SDD_SPEC_ROOT="kb/01_spec"
  printf 'ENT %s\n' $(sdd_find_entities "kb")
  printf 'ACT %s\n' $(sdd_find_actions  "kb")
) > "$ROOT/shape.out"
has   "find_entities keeps the entity on a KB-wide scope" \
      "ENT kb/01_spec/_modules/auth/_domain/user/user.entity.md" "$(cat "$ROOT/shape.out")"
has   "find_actions keeps the action on a KB-wide scope" \
      "ACT kb/01_spec/_modules/auth/_domain/user/user.create.action.md" "$(cat "$ROOT/shape.out")"
hasnt "find_entities ignores a dotted-slug screen" \
      "user.profile" "$(cat "$ROOT/shape.out")"

# A multi-word module slug is kebab-case. Asserted as DISCOVERY rather than as an
# absence of errors: a finder that cannot see a file skips it in silence, and every
# rule, the id index and the emanation frontier are built on these lists.
mkdir -p "$SPEC/_modules/knowledge-base/_domain/entry"
: > "$SPEC/_modules/knowledge-base/_domain/entry/entry.entity.md"
: > "$SPEC/_modules/knowledge-base/_domain/entry/entry.promote.action.md"
(
  cd "$ROOT" || exit 1
  SDD_SPEC_ROOT="kb/01_spec"
  printf 'ENT %s\n' $(sdd_find_entities "kb")
  printf 'ACT %s\n' $(sdd_find_actions  "kb")
) > "$ROOT/kebab.out"
has   "find_entities discovers a kebab-case module" \
      "ENT.*knowledge-base/_domain/entry/entry.entity.md" "$(cat "$ROOT/kebab.out")"
has   "find_actions discovers a kebab-case module" \
      "ACT.*knowledge-base/_domain/entry/entry.promote.action.md" "$(cat "$ROOT/kebab.out")"
hasnt "the extension still tells the two apart" \
      "ENT.*promote" "$(cat "$ROOT/kebab.out")"

# ─────────────────────────────────────────────────────────────────────────────
# The two halves of a wikilink, as `sdd_links` reads them — one link, two
# questions, opposite answers
#
# `[[target|display]]` declares an id on the right (the text field) and points at
# a file on the left (the target field). A rule that asked the wrong half
# reported every aliased prose link in a vault as dangling.
# ─────────────────────────────────────────────────────────────────────────────

# wl <link> <field> — one field (3 target, 4 text) of the only link in a one-line file.
wl() {
  printf '%s\n' "$1" > "$ROOT/wl.md"
  (
    SDD_KB_ROOT="$ROOT/wl-kb"; SDD_SPEC_ROOT="$SDD_KB_ROOT/01_spec"
    SDD_LINK_INDEX_FILE=""; SDD_ENTITY_INDEX_FILE=""
    mkdir -p "$SDD_SPEC_ROOT"
    sdd_link_index
    sdd_links "$ROOT/wl.md" | cut -f"$2"
    rm -f "$SDD_LINK_INDEX_FILE" "$SDD_ENTITY_INDEX_FILE"
  )
}

eq "unwrap reads the declared id"           "$(wl '[[auth.user|auth::user]]' 4)" "auth::user"
eq "target reads the file it points at"     "$(wl '[[auth.user|auth::user]]' 3)" "auth.user"
eq "an alias is never the target"           "$(wl '[[adr-x|the audit decision]]' 3)" "adr-x"
eq "a path target survives whole"           "$(wl '[[../../01_adr/adr-x|the audit decision]]' 3)" "../../01_adr/adr-x"
eq "the table-cell escape is not the target" "$(wl '[[a.b\|a::b]]' 3)" "a.b"
eq "a bare link is its own target"          "$(wl '[[adr-x]]' 3)" "adr-x"
eq "only the first pipe divides"            "$(wl '[[adr-x|a|b]]' 3)" "adr-x"

eq "unwrap_links: a wikilink reads as its right half" \
   "$(printf 'see [[auth.user|auth::user]] and [[adr-x]]\n' | sdd_unwrap_links)" "see auth::user and adr-x"
eq "unwrap_links: a Markdown link reads as its text, adjacent ones too" \
   "$(printf 'see [the ADR](../a.adr.md)[b](c.md) ![img](p.png)\n' | sdd_unwrap_links)" "see the ADRb ![img](p.png)"

# ─────────────────────────────────────────────────────────────────────────────
# sdd_links — every link in a file, both forms, with the file each one names
# ─────────────────────────────────────────────────────────────────────────────

L="$ROOT/links/kb/01_spec"
mkdir -p "$L/_modules/auth/_domain/user" "$L/_adr" "$L/_faces/app/_screens" "$L/_design-system/patterns" "$L/_migration"
printf -- '---\nid: auth::user::create\n---\n' > "$L/_modules/auth/_domain/user/user.create.action.md"
printf -- '---\nid: app.users.list\n---\n' > "$L/_faces/app/_screens/list.screen.md"
printf '{"screens":{"users.list":"app.users.list"}}\n' > "$L/_migration/id-map.json"
: > "$L/_adr/auth-sessions.adr.md"
: > "$L/_design-system/patterns/list.pattern.md"
cat > "$L/_modules/auth/_domain/user/user.entity.md" <<'EOF'
---
id: auth.user
requires: ["[[auth.user.create|auth::user::create]]"]
links:
  - "[create](user.create.action.md)"
---
Prose [the decision](../../../../_adr/auth-sessions.adr.md#context) and [gone](./gone.md).
Spans `[[adr-span]]` and ``a `[s](s.md)` b`` are examples; ![img](p.png), [web](https://x.org/a.md) and [top](#top) are not KB links.
| [[auth.user.create\|auth::user::create]] | [x\|y](<user.create.action.md> "title") | [](user%2Ecreate.action.md) |
```
[[fenced]] [f](f.md)
```
[[../../01_adr/adr-auth-sessions]] [[users.list]] [[../patterns/list]] [[nowhere]]
EOF
(
  cd "$ROOT/links" || exit 1
  SDD_KB_ROOT="kb"; SDD_SPEC_ROOT="kb/01_spec"; SDD_ENTITY_INDEX_FILE=""
  sdd_link_index
  sdd_links "kb/01_spec/_modules/auth/_domain/user/user.entity.md"
  rm -f "$SDD_LINK_INDEX_FILE" "$SDD_ENTITY_INDEX_FILE"
) > "$ROOT/links.out"
links="$(cat "$ROOT/links.out")"
U="kb/01_spec/_modules/auth/_domain/user"
T="$(printf '\t')"

has   "links: a frontmatter wikilink, resolved by id" \
      "^3${T}wiki${T}auth.user.create${T}auth::user::create${T}$U/user.create.action.md\$" "$links"
has   "links: a quoted frontmatter list item" \
      "^5${T}md${T}user.create.action.md${T}create${T}$U/user.create.action.md\$" "$links"
has   "links: a path joins the linking file's directory and keeps its anchor as written" \
      "^7${T}md${T}../../../../_adr/auth-sessions.adr.md#context${T}the decision${T}kb/01_spec/_adr/auth-sessions.adr.md\$" "$links"
has   "links: a missing file resolves to nothing" \
      "^7${T}md${T}./gone.md${T}gone${T}\$" "$links"
hasnt "links: a code span is skipped"          "adr-span" "$links"
hasnt "links: a span holding backticks is one" "${T}s\.md" "$links"
hasnt "links: an image is not a link"          "p\.png"   "$links"
hasnt "links: an external URL is skipped"      "x\.org"   "$links"
hasnt "links: an in-file anchor is skipped"    "#top"     "$links"
has   "links: a table-escaped pipe is not part of a wikilink target" \
      "^9${T}wiki${T}auth.user.create${T}auth::user::create${T}$U/user.create.action.md\$" "$links"
has   "links: angle brackets and a title wrap the path; the escaped pipe reads as text" \
      "^9${T}md${T}user.create.action.md${T}x|y${T}$U/user.create.action.md\$" "$links"
has   "links: a link with no text reports its target; percent-escapes decode" \
      "^9${T}md${T}user%2Ecreate.action.md${T}user%2Ecreate.action.md${T}$U/user.create.action.md\$" "$links"
hasnt "links: a fenced block is skipped" "fenced" "$links"
has   "links: a path-shaped wikilink means its last segment" \
      "^13${T}wiki${T}../../01_adr/adr-auth-sessions${T}.*${T}kb/01_spec/_adr/auth-sessions.adr.md\$" "$links"
has   "links: an old screen id resolves through the migration's id map" \
      "^13${T}wiki${T}users.list${T}users.list${T}kb/01_spec/_faces/app/_screens/list.screen.md\$" "$links"
has   "links: a catalog wikilink resolves by name" \
      "^13${T}wiki${T}../patterns/list${T}.*list.pattern.md\$" "$links"
has   "links: an unresolved wikilink has no path" "^13${T}wiki${T}nowhere${T}nowhere${T}\$" "$links"
eq    "links: one row per link" "$(printf '%s\n' "$links" | grep -c .)" "11"
eq    "links: the target's id comes from the file it resolves to" \
      "$(sdd_artifact_id "$ROOT/links/kb/01_spec/_adr/auth-sessions.adr.md")" "adr-auth-sessions"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
