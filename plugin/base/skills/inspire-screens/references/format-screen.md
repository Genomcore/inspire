# Screen file format
> Part of [inspire-screens](../SKILL.md). Read before writing or reviewing any screen file.

The format spec for screen files. SKILL.md owns the flows and the triangulation
matrix; [`screen-lifecycle.md`](screen-lifecycle.md) owns the state machine; this
file owns the on-disk shape.

A screen file lives at `inspire_kb/05_screens/{module}/{screen}.md`, or at
`05_screens/{surface}/{module}/{screen}.md` once the roster declares two or more UI
surfaces ([`_references/surface-scope.md`](../../_references/surface-scope.md)).
**The path is where the file sits; the `id` is what the file is.**

## Canonical shape

```markdown
---
id: users.list           # minted once, never re-derived from location
module: users
screen: list
lifecycle: draft         # draft | accepted | stable | superseded
---

# Users

**Features:** FEAT-01, FEAT-02
**Pattern:** [[../patterns/list]]
**Components:** [[../components/data-table]]

## Purpose

An administrator comes here to find one user among many. The roster leads, so
the first thing the reader sees is who exists in the workspace at all;
everything else on the screen serves that search.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | primary table feed |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [[auth.user.create\|auth::user::create]] | primary action | → [[users.detail]] | state `form-error` |
| `delete` | [[auth.user.delete\|auth::user::delete]] | row action | refresh `main` | state `error` |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [[users.detail]] | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message and the create action |
| `form-error` | `create` rejects | the field errors, inline, with the form still filled |
| `error` | `delete` rejects | the failure message, with the row still in place |
```

Required: the frontmatter identity block, the H1 title, the `**Features:**` line,
a non-empty `## Purpose`, and `## Bindings` with at least one of its four
subsections. Optional and presence-free: `**Pattern:**`, `**Components:**`,
`## Module-specific deviations`, `## Current prototype`, `## Notes`.

## Identity — the id is the referent

1. **Default mint: `{module}.{screen}`.** The id is minted when the file is
   created and is **write-once**: never re-derived from the file's location, never
   edited afterwards.
2. **Ids are unique KB-wide.** When a second surface needs a screen whose default
   id is taken — `admin` and `portal` both wanting `users.list` — the *newcomer*
   mints `{surface}.{module}.{screen}`. The screen already holding the id keeps it.
   A surface split therefore moves files without touching a single id.
3. **Move versus change.** Same `id`, new path: a **move** — claims and
   fingerprints are stable and nothing re-emanates. Changed `id`: a **new
   referent** — the old screen retires through its lifecycle and the new one enters
   the frontier. There is no third case.
4. **The module is referent, not position.** Re-homing a screen under another
   module is a new referent, never a move: `module:` and the path's module
   directory must agree, and the validator says so when they do not. Only the
   surface placement is positional.
5. **`screen:` is not the filename.** Both name the same thing at creation, and
   they may diverge later without consequence: the file name is positional, and
   renaming a file is a move. Route derivation reads the field, never the name.

## Routes derive — nothing authors one

A screen's route derives from its declared `module:` and `screen:` fields, exactly
as an action id derives its endpoint. The default rendering is
`/{module}/{screen}`; a UI surface contributes **only its shell prefix**
(`{shell}/{module}/{screen}`), and the exact rendering belongs to the framework
profile, like every other binding convention.

The id string is **not** a route input. A collision-minted `admin.users.list`
(`module: users`, `screen: list`) still renders `/users/list` under the admin
shell, with no doubled surface segment.

Consequences worth stating plainly: a route and an id can never disagree, because
there is no second place to write a route down; and moving or reusing a screen
across UI surfaces is free and declaration-only — the id, the route and every claim
survive the move, and the surface list is the only edit. Screen files therefore
carry **no route text**: not in the H1, not in a section of their own. The derived
map is rendered on demand by `/inspire-screens routes`.

## Lifecycle

`lifecycle:` takes the shared 4-state enum — `draft` → `accepted` → `stable`,
plus `superseded` as the escape hatch — defined once in
[`_references/lifecycle-rules.md`](../../_references/lifecycle-rules.md) and
walked by `/inspire-screens promote`. What each state gates for a screen, and how
the emanation frontier reads it, is [`screen-lifecycle.md`](screen-lifecycle.md).

## Header lines

| Line | Required | What it declares |
|---|---|---|
| `**Features:**` | yes | the feature ids this screen realizes, comma-separated |
| `**Pattern:**` | no | one repeatable layout, as a wikilink into `patterns/` |
| `**Components:**` | no | the shared components this screen instantiates, as wikilinks into `components/` |

`**Pattern:**` is a **peer layout dependency**, not the screen's definition: it
constrains presentation and nothing else, and a screen that names none is not a
special case — it simply inherits no shared layout. Its declarations stand on
their own either way. Both lines are **ordering edges** for the emanation loop: a
shared layout and a shared component are units it emanates too, so a screen
declaring them waits for their wave instead of waiting for someone to build them
by hand first
([`_references/emanation-plan.md`](../../_references/emanation-plan.md)).

## `## Purpose` — who comes here, and what for

One paragraph of prose, directly under the header lines: **who** comes to this
screen, for **which task**, and **what they see first**. Prose only — no table,
no bullet list — the way an action descriptor opens with its own `## Purpose`.

It is orientation for a human reader and intent for the emanating agent, which
would otherwise have to reconstruct the screen's job from the feature links.
Two boundaries keep it from turning into a second contract:

- **It never restates the bindings.** The `## Bindings` rows are the contract,
  and a paragraph re-listing them is one more place to drift. Say why the screen
  exists; let the rows say what it declares.
- **It never names a route.** Routes derive (§ Routes derive — nothing authors
  one), and a route written into a paragraph is still a route written down.

Say it in the product's own words, in present state, and keep it short: a reader
who needs three paragraphs to learn what a screen is for is reading a screen
that does two jobs.

## `## Bindings` — the screen's own semantics

Four subsections, and the set is closed. Each takes a table whose **first column is
a screen-local key**:

| Subsection | Columns | Declares |
|---|---|---|
| `### Data` | Key, Action, Notes | which actions feed this screen |
| `### Dispatches` | Key, Action, Trigger, On success, On error | which actions this screen invokes, and what follows |
| `### Navigation` | Key, Target, Trigger | the transitions **no dispatch on this screen causes** |
| `### States` | Key, When, Presentation | the keyed states this screen can be in |

- **Keys are declared, screen-local, and unique per subsection** — not action ids,
  because one action may be dispatched from two places with different outcomes.
  The default key is the action id's final segment when the action is dispatched
  once; an explicit distinct key is mandatory on duplicates.
- **Outcomes are attributes of their dispatch, not claims of their own.**
  `On success` and `On error` take one of three forms, and nothing else:
  `→ [[{screen-id}]]` (navigate), `state \`{key}\`` (a key declared in
  `### States`), or `refresh \`{key}\`` (a key declared in `### Data`). A dash
  means the dispatch has no declared outcome on that side.
- **One transition, one declaration, one claim.** A transition a dispatch causes
  is that dispatch's `On success` / `On error` outcome, **never** a Navigation
  row. `### Navigation` declares only the transitions no dispatch on this screen
  causes: a row click, a menu link, a back link, a tab. Declaring a
  post-dispatch transition in both places mints two claims for one fact — the
  dispatch's fingerprint *and* `{id}/nav/{key}` — which is exactly the
  double-keying that outcomes-as-attributes exists to prevent. Nothing checks
  this mechanically, because the same target screen may legitimately be reached
  both ways: one row click and one dispatch outcome are two transitions, not a
  duplicate.
- **Navigation targets name screens by id**, never by route or path. Screen-id
  wikilinks resolve through the id index in `.inspire/bin/wikilinks-resolve.sh`,
  so a positional file name never has to match one.
- **A state's `When` must reference something declared** — a data key, a dispatch
  key, or a deviation. A free-floating state is a finding. The reference anchors
  **only through backticks**: `` `main` returns zero rows `` anchors on the data
  key `main`, while the same sentence written `main returns zero rows` does not
  and is reported as unanchored. The backticks are what separate a declared key
  from an English word that happens to spell it.
- **A pipe-syntax wikilink inside a table cell escapes its pipe** (`\|`), or the
  cell ends early. A bare colon-form link (`[[auth::user::list]]`) is equally
  valid and needs no escape.
- Drop any subsection the screen has nothing to declare in. `## Bindings` itself
  stays, with at least one subsection under it.

## Claims

Every binding row is one claim, keyed by the screen id and the row's own key:

| Family | Claim id |
|---|---|
| data | `{id}/data/{key}` |
| dispatch | `{id}/dispatch/{key}` |
| navigation | `{id}/nav/{key}` |
| state | `{id}/state/{key}` |

A row's cells feed that claim's fingerprint — the dispatch's outcomes included, so
changing an outcome re-emanates that one dispatch and nothing else. Because every
key is screen-keyed rather than slot-keyed, a pattern change never re-keys a claim,
and neither does a move.

## The pattern join

Where `**Pattern:**` names a layout, the pattern's `## Regions` table is checked
against this screen's bindings. Each region declares `Fill` (`required` |
`optional`) and `Accepts` (one or more of `data` · `dispatch` · `nav` · `static`).
A **required** region whose `Accepts` names a binding kind demands at least one
binding of that kind: a `list` layout with no data binding is a finding.

**Both vocabularies are closed**, and a value outside them is a warning on the
**pattern** file — not on the screens that adopt it, and once however many do.
The join can only ignore a token it does not recognize, so an out-of-vocabulary
`Accepts` would otherwise buy the region silence instead of a check: the region
that most needs a binding would be the one demanding none.

This is a check on the join, never a transfer of ownership. Regions are holes; a
component's props stay in the component's own catalog entry; the screen is the one
artifact where props and regions meet.

## Old shape → new shape

The shapes below are what a pre-0.9 screen carries — every screen any released
version wrote, since the identity block first ships at 0.9. Each is a **derivation
refusal**, named so the operator is told which skill touches the file rather than
handed an empty section:

| Old shape | New shape |
|---|---|
| no frontmatter at all | the identity block — `id` · `module` · `screen` · `lifecycle` |
| the route in the H1 (`# Users — \`/users\``) | the H1 is the title alone; the route derives |
| `**Pattern:** bespoke` | omit the line; a screen with no shared layout declares none |
| `## Instantiation` prose ("**Data:** the user entity") | `## Bindings`, keyed, one row per declaration |
| a pattern's `## Slots` filled slot by slot | the screen's own bindings; the pattern's `## Regions` are joined, not filled in |
| outcomes as prose ("→ `/users/:id`") | `→ [[{screen-id}]]`, a screen id, never a route |

The presence of `id:` in frontmatter is the deterministic marker of the new shape:
every new-shape screen has one, and no old-shape screen does.

**An absent `## Purpose` gets no row of its own**, and this is the same treatment
`## Bindings`'s own absence gets. Every row above names something the old file
**carries** and says what that text becomes — `## Instantiation` earns a row
because its declarations move into keyed rows, and the identity block earns one
because the H1 route and the missing frontmatter are text on disk today. A screen
that never had a purpose paragraph carries nothing to convert: there is no old
sentence to rewrite, only a section to author. That is exactly what
`sections-present` reports as a missing required part, and a catalogue row saying
"nothing → write one" would add a second name for one finding.
