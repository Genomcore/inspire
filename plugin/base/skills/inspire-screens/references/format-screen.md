# Screen file format
> Part of [inspire-screens](../SKILL.md). Read before writing or reviewing any screen file.

The format spec for screen files. SKILL.md owns the flows and the triangulation
matrix; [`screen-lifecycle.md`](screen-lifecycle.md) owns the state machine; this
file owns the on-disk shape.

A screen file lives at `inspire_kb/01_spec/_faces/{face}/_screens/{slug}.screen.md`,
in the face its id names ([`_references/face-scope.md`](../../_references/face-scope.md)).
Tools find it by its `.screen.md` extension, never by its directory.
**The path is where the file sits; the `id` is what the file is.**

## Canonical shape

```markdown
---
id: admin.users-list     # {face}.{slug}, minted once, never re-derived from location
module: users
screen: list
lifecycle: draft         # draft | accepted | stable | superseded
---

# Users

**Features:** FEAT-01, FEAT-02
**Pattern:** [list](../../../_design-system/patterns/list.pattern.md)
**Layout:** [collection](../../../_design-system/layouts/collection.layout.md)
**Components:** [data-table](../../../_design-system/components/data-table.component.md), [person-chip](../../../_design-system/components/person-chip.component.md)

## Purpose

An administrator comes here to find one user among many. The user list leads, so
the first thing the reader sees is who exists in the workspace at all;
everything else on the screen serves that search.

## Bindings

### Parameters

| Key | In | Type | Required | Notes |
|---|---|---|---|---|
| `q` | query | string | no | the search text, kept across a reload |

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [auth::user::list](../../../_modules/auth/_domain/user/user.list.action.md) | primary table feed, filtered by param `q` |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [auth::user::create](../../../_modules/auth/_domain/user/user.create.action.md) | primary action | → [admin.user-detail](user-detail.screen.md) param `id` | state `form-error` |
| `delete` | [auth::user::delete](../../../_modules/auth/_domain/user/user.delete.action.md) | row action | refresh `main` | state `error` |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [admin.user-detail](user-detail.screen.md) param `id` | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message and the create action |
| `filtered` | `q` is set | the search text in the field, and an action that clears it |
| `form-error` | `create` rejects | the field errors, inline, with the form still filled |
| `error` | `delete` rejects | the failure message, with the row still in place |

## Render

### Table

| Value | Field type | Component | Treatment | Align | Narrow |
|---|---|---|---|---|---|
| Name | person | `person-chip` | `lucide-user` 16px, the name in `{font.size.sm}` | left | sticky |
| Email | text | `data-table` cell | `{color.text.secondary}` | left | hidden below laptop |
| Last seen | date | `data-table` cell | relative, the absolute date on hover; on touch, a tap on the cell shows it | right | scroll |
```

Required: the frontmatter identity block, the H1 title, the `**Features:**` line,
a non-empty `## Purpose`, and `## Bindings` with at least one of its five
subsections. Optional and presence-free: `**Pattern:**`, `**Layout:**`,
`**Components:**`, `## Render`, `## Module-specific deviations`,
`## Current prototype`, `## Notes`. Two of them are owed rather than free: a screen
naming a pattern names the layout that frames it, and a screen declaring `### Data`
carries `## Render` — `screen-presentation.sh` warns on either, and derivation never
reads them.

## Identity — the id is the referent

1. **The mint: `{face}.{slug}`.** The face is the one the screen belongs to; the
   slug is the file's name without `.screen.md`. The id is minted when the file is
   created and is **write-once**: never re-derived from the file's location, never
   edited afterwards. A slug never starts with `_`.
2. **The slug is unique within the face,** so the id is unique across the KB. Two
   faces may each hold a `users-list`: `admin.users-list` and
   `portal.users-list` are two screens.
3. **Move versus change.** Same `id`, new path or new file name: a **move** —
   claims and fingerprints are stable and nothing re-emanates. Changed `id`: a
   **new referent** — the old screen retires through its lifecycle and the new one
   enters the frontier. There is no third case.
4. **The face is referent, not position.** A screen belongs to the face its id
   names, and its file sits in that face's `_screens/`. Taking a screen to another
   face is a new referent, never a move: `create` it in the other face and
   supersede the old one. When two faces need the same screen, each keeps its own,
   and what they share becomes a layout or a pattern in `_design-system/`.
5. **`module:` and `screen:` are written once too.** They give the route. Re-homing
   a screen under another module changes its route, so it is a new referent.
6. **`screen:` is not the slug.** `screen:` is unique within a module in one face
   and is a route segment. The slug is unique within the face and is an identity.
   A face with five detail screens has five `screen: detail` and five distinct
   slugs (`study-detail`, `case-detail` …). Route derivation reads the field, never
   the slug.

## Routes derive — nothing authors one

A screen's route derives from its declared `module:` and `screen:` fields, exactly
as an action id derives its endpoint. The rendering is
`{shell}/{module}/{screen}`, where `shell` is the `shell:` of the face's
`{face}.face.md`, and every `path` parameter the screen declares appends one
segment, in the order its `### Parameters` rows are written
(`/admin/users/detail/{id}`). The exact rendering — the parameter syntax included —
belongs to the framework profile, like every other binding convention.

The id string is **not** a route input. `admin.users-list` (`module: users`,
`screen: list`) renders `/admin/users/list`: the face appears once, as the shell,
and the slug never appears.

A route and an id can never disagree, because there is no second place to write a
route down. Screen files therefore carry **no route text**: not in the H1, not in a
section of their own. The derived map is rendered on demand, per face, by
`/inspire-screens routes`.

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
| `**Pattern:**` | no | one repeatable structure: a `*.pattern.md` entry, linked by its file (`[list](../../../_design-system/patterns/list.pattern.md)`) |
| `**Layout:**` | no | the page frame it sits in: a `*.layout.md` entry, linked — or every frame, outermost first, when one nests inside another |
| `**Components:**` | no | the shared components this screen instantiates: `*.component.md` entries, linked |

A catalog link is a relative Markdown link to the entry's file, its id as the text. A linked entry that does not exist yet is created in
the same turn from its template, at `**State:** to-extract`
([`screen-catalog.md`](screen-catalog.md)).

`**Pattern:**` and `**Layout:**` are **peer presentation dependencies**, not the
screen's definition: they constrain presentation and nothing else, and a screen
that names neither is not a special case — it inherits no shared structure and no
shared frame. Its declarations stand on their own either way. A screen naming a
pattern names the layout that frames it, because a structure with no measurements
is a rebuild the implementer has to invent. `**Pattern:**`, `**Layout:**` and
`**Components:**` are **ordering edges** for INSPIRE Factory: a shared pattern,
layout and component are units it emanates too, so a screen declaring them waits
for their wave instead of waiting for someone to build them by hand first. The
face shell needs no line: it frames every route, so every screen waits for its
face's shell layout once that entry exists.

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

Five subsections, and the set is closed. Each takes a table whose **first column is
a screen-local key**:

| Subsection | Columns | Declares |
|---|---|---|
| `### Parameters` | Key, In, Type, Required, Notes | the inputs this screen is opened with |
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
  `→ [{screen-id}]({path})` (navigate), `state \`{key}\`` (a key declared in
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
- **Navigation targets are links to screen files**, never routes
  ([kb-links.md](../../_references/kb-links.md)); the link text is the screen id. A
  target that does not exist yet is created in the same turn from
  [`screen.template.md`](../templates/screen.template.md), at `lifecycle: draft`.
- **Every bound action is exposed to the face.** An action a `### Data` or
  `### Dispatches` row binds belongs to a bundle the face lists in `bundles:`.
  `.inspire/bin/face-exposure.sh` checks it.
- **A state's `When` must reference something declared** — a data key, a dispatch
  key, a parameter key, or a deviation. A free-floating state is a finding. The reference anchors
  **only through backticks**: `` `main` returns zero rows `` anchors on the data
  key `main`, while the same sentence written `main returns zero rows` does not
  and is reported as unanchored. The backticks are what separate a declared key
  from an English word that happens to spell it.
- Drop any subsection the screen has nothing to declare in. `## Bindings` itself
  stays, with at least one subsection under it.

## `### Parameters` — what the screen is opened with

A screen's inputs are stated, never deduced from the code that happens to read
them. One row per input:

| Column | Holds |
|---|---|
| `Key` | the parameter's name — screen-local, and the name a transition passes |
| `In` | `path` or `query`: where it travels |
| `Type` | its semantic type, resolved like every other `Type` cell in the KB |
| `Required` | `yes` or `no` |
| `Notes` | what it selects or changes, in the product's words |

- **A parameter need not feed a data binding.** A mode flag — a quick view
  versus an advanced one — loads nothing and is still an input: declare it, and
  anchor the state it produces on its key.
- **A path parameter is required.** A path segment cannot be absent, so
  `path` with `Required: no` is a finding; an optional input travels in the
  query.
- **A record inside a record is two path parameters**, outer first — an
  annotation of a study declares `study` then `annotation`. There is no nested
  shape: the route still derives from `module` + `screen`, and how the segments
  interleave is the framework profile's rendering.
- **Reliance is declared with `param \`{key}\``.** A `### Data` row that loads by
  a parameter names it in its cells (`filtered by param \`q\``) and must name one
  this screen declares. A transition that passes one — a `### Navigation`
  target, or a `→ [{screen-id}]({path})` dispatch outcome — writes it after the link
  (`[admin.user-detail](user-detail.screen.md) param \`id\``), and it must be one the **target** declares.
  Write the token once per parameter.
- **A screen with no URL reads the same table.** On a native target the rows
  are the screen's typed inputs — the arguments its navigation passes —
  and `In` is the profile's to map; the declaration does not change.

Every parameter is a claim (§ Claims), so each one, mode flags included, is
covered by a test of its own: an uncovered parameter fails the gate like any
other uncovered claim.

## `## Render` — how each value is drawn

The bindings say what the screen shows; `## Render` says how. One H3 per region of
the pattern, in reading order, each holding a table:

| Column | Holds |
|---|---|
| `Value` | the column, field, meta value or control, in the product's words |
| `Field type` | its field type from `design-system.md`, or `—` for a control |
| `Component` | the catalog component that draws it, backticked, with its variant: `` `button` `outline` ``; `+` joins two |
| `Treatment` | tokens by path in braces, the glyph by library and name, the copy, and any hover state with its touch equivalent |
| `Align` | `left` · `centre` · `right` |
| `Narrow` | on a table of columns only: `always` · `sticky` · `scroll` · `hidden below {width}` — what the column does below the widest range |

Four rules hold it:

- **Every value the screen shows has a row.** A value named only in prose — a
  column list in a sentence — leaves the implementer to pick a treatment, and the
  one they pick is the generic one.
- **Every component it names has an entry.** Name a component that has no
  `{name}.component.md`, and write its entry at `**State:** to-extract` in the same
  turn ([`screen-catalog.md`](screen-catalog.md)).
- **Every glyph is named.** `lucide-folder`, never "a folder icon" or "the resource
  icon".
- **No measurement of the frame.** A width, a padding or a gap of a region belongs
  to the layout; Render holds what is drawn inside it.

`## Render` **mints no claim.** Derivation does not read it, so editing a treatment
never re-emanates a unit, and adding the section to a `stable` screen leaves its
contract untouched.

## Claims

Every binding row is one claim, keyed by the screen id and the row's own key:

| Family | Claim id |
|---|---|
| parameter | `{id}/param/{key}` |
| data | `{id}/data/{key}` |
| dispatch | `{id}/dispatch/{key}` |
| navigation | `{id}/nav/{key}` |
| state | `{id}/state/{key}` |

A row's cells feed that claim's fingerprint — the dispatch's outcomes included, so
changing an outcome re-emanates that one dispatch and nothing else, and the
parameters a transition passes included, so passing one more re-emanates that
one transition. Because every
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
| an id shaped `{module}.{screen}` or `{surface}.{module}.{screen}`, from a layered KB | `{face}.{slug}`, written once by `/inspire:migrate`, which records every change in `_migration/id-map.json`; never hand-edited |
| a wikilink to a catalog entry (`[[list]]`, `[[../patterns/list]]`) | a Markdown link to its file (`[list](../../../_design-system/patterns/list.pattern.md)`), converted by `/inspire:migrate` |
| the route in the H1 (`# Users — \`/users\``) | the H1 is the title alone; the route derives |
| `**Pattern:** bespoke` | omit the line; a screen with no shared layout declares none |
| `## Instantiation` prose ("**Data:** the user entity") | `## Bindings`, keyed, one row per declaration |
| a pattern's `## Slots` filled slot by slot | the screen's own bindings; the pattern's `## Regions` are joined, not filled in |
| outcomes as prose ("→ `/users/:id`") | `→ [{screen-id}]({path})`, a link to a screen file, never a route |

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
