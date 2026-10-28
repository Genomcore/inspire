# 05 · Screens

Screen specifications and the **shared component catalog** — the visual and
interaction contract that later gets turned into code. A **screen** is the UI
spec for one navigable view; here it's named "screen" because that reads clearer.

- **Skill:** `inspire-screens` (create, validate, promote and route screens).
- **Layout** — the shape is deterministic from the surface roster (specifically
  the count of `kind: ui` entries in
  [`00_bootstrap/surfaces.md`](../00_bootstrap/surfaces.md)), never from history:

  Roster absent, or a single UI surface (today's default, and every suite-of-one):
  ```
  05_screens/
    patterns/            # reusable structures — their regions (starters: list, detail)
    layouts/             # the page frames — their geometry and breakpoints
    components/          # the shared component catalog (reused when coding)
    {module}/            # screens per module
    design-system.md     # the live design system — seeded at install
    design-tokens.json   # its token values, W3C Design Tokens — seeded at install
  ```

  Two or more UI surfaces declared — surface-first:
  ```
  05_screens/
    patterns/            # reusable structures — suite-wide, top level
    layouts/             # the page frames — suite-wide, top level
    components/          # the shared component catalog — suite-wide, top level
    design-system.md     # the live design system — suite-wide, top level
    design-tokens.json   # its token values — suite-wide, top level
    shared/{module}/     # screens used by more than one UI surface
    {surface}/{module}/  # screens per module, one tree per UI surface
  ```

  `patterns/`, `layouts/`, `components/`, `design-system.md` and
  `design-tokens.json` never move — they sit beside
  the surface trees at top level in both shapes; they are never duplicated inside
  a surface directory. Full rules on surfaces, `shared/` and scope resolution are
  in
  [`.claude/skills/_references/surface-scope.md`](../../.claude/skills/_references/surface-scope.md).
- **`design-system.md`** is the project's live design system (typography, color,
  density, layout, icons, supported viewports, and the reference the layer is
  measured from), and **`design-tokens.json`** holds its values in the
  [W3C Design Tokens format](https://www.designtokens.org/tr/drafts/format/): the
  markdown says what a token means, the JSON says what it is, and every other file
  cites a token by its path in braces. Both are **seeded by `materialize.sh`** from
  the defaults [`00_bootstrap/theme.md`](../00_bootstrap/theme.md) and
  [`00_bootstrap/theme.tokens.json`](../00_bootstrap/theme.tokens.json), then owned
  by `/inspire-bootstrap design-system` (screens **read** the tokens, they don't
  edit them). (So neither is shipped in the bare template; they appear after
  `/inspire:init` runs. An upgraded project gets its token file from
  `/inspire-bootstrap design-system backfill`.)

## Four ownerships

Design-system tokens sit above everything. Below them, patterns, layouts and
components are **siblings** — none depends on another by construction — and
screens compose them:

| Owner | Owns | Never owns |
|---|---|---|
| a **component** entry | its props, and the states it renders | where it is placed |
| a **pattern** entry | its regions (named holes) | the fields its content shows, and any measurement |
| a **layout** entry | the geometry those regions sit at, per supported width | what fills them |
| a **screen** | the wiring: data → components, components → regions, and how each value it shows is drawn (`## Render`) | tokens, geometry, props |

A region is a hole, never a mirror of some component's props. That is why a
pattern's `## Regions` table says only how a hole is filled (`required` /
`optional`) and what kind of content it accepts (`data` · `dispatch` · `nav` ·
`static`).

All three catalog entries carry a `**State:**` line — `to-extract` (authored, no code
yet) or `implemented` (built). That line is the entry's lifecycle: the emanation
loop reads it exactly as it reads a domain artifact's `lifecycle:`, so a
`to-extract` entry is a unit it emanates and the screens naming it wait for its
wave rather than refusing over it.

The entries in [`components/`](components) are also the reference when the UI is
built — in the prototype ([`/prototype`](../../prototype)) or in production.

## What a screen file carries

- **An identity block** — `id` · `module` · `screen` · `lifecycle`. The `id` is
  minted once and never re-derived from the file's location: the path says where
  the file sits, the id says what it is. Moving a file is a move; changing an id
  makes a different screen.
- **A `## Purpose` paragraph** — who comes to this screen, for which task, and
  what they see first. One paragraph of prose, required: it orients a human
  reader and gives the emanating agent the screen's intent, which the feature
  links alone do not carry. It restates no binding and names no route.
- **Its own `## Bindings`** — the input parameters, data sources, dispatches,
  navigation targets and states it declares, each keyed screen-locally. A
  parameter — a record id, a filter, a mode flag — says whether it travels in the
  path or the query; the spec states it rather than leaving the code to deduce
  it. These stand whether or not a
  pattern is named, and each row is one claim the emanation loop can cover. A
  transition a dispatch causes is that dispatch's outcome, never also a
  navigation row: one transition, one declaration, one claim.
- **Optional dependencies** — a `**Pattern:**` line naming one shared structure, a
  `**Layout:**` line naming the frame it sits in, and a `**Components:**` line
  naming the shared components it instantiates. Peer dependencies, all three: they
  constrain presentation and gate promotion, never define the screen.
- **A `## Render` table** — every column, field and meta value the screen shows,
  bound to its field type, the component that draws it, its treatment (tokens and
  the named glyph) and its alignment; a table's columns add what each does at
  narrow widths. Presentation only: it mints no claim.
- **No route.** Routes derive from `module:` + `screen:`, prefixed by the
  surface's shell. `/inspire-screens routes` renders the map; nothing stores it.

The full on-disk shape, the claim families and the old-shape catalogue are in
`.claude/skills/inspire-screens/references/format-screen.md`.

Screens realise features ([`03_features`](../03_features)) and must stay aligned
with the specs in [`04_domain`](../04_domain). Their `lifecycle:` takes the same
4-state enum as the domain layer — `draft` → `accepted` → `stable`, plus
`superseded` — walked by `/inspire-screens promote`.
