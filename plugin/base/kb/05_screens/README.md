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
    patterns/            # reusable layouts — their regions (starters: list, detail)
    components/          # the shared component catalog (reused when coding)
    {module}/            # screens per module
    design-system.md     # the live design system — seeded at install
  ```

  Two or more UI surfaces declared — surface-first:
  ```
  05_screens/
    patterns/            # reusable layouts — suite-wide, top level
    components/          # the shared component catalog — suite-wide, top level
    design-system.md     # the live design system — suite-wide, top level
    shared/{module}/     # screens used by more than one UI surface
    {surface}/{module}/  # screens per module, one tree per UI surface
  ```

  `patterns/`, `components/` and `design-system.md` never move — they sit beside
  the surface trees at top level in both shapes; they are never duplicated inside
  a surface directory. Full rules on surfaces, `shared/` and scope resolution are
  in
  [`.claude/skills/_references/surface-scope.md`](../../.claude/skills/_references/surface-scope.md).
- **`design-system.md`** is the project's live design system (tokens, typography,
  color, density, layout). It's **seeded by `materialize.sh`** by copying the default
  template [`00_bootstrap/theme.md`](../00_bootstrap/theme.md), then owned by
  `/inspire-bootstrap design-system` (screens **read** its tokens, they don't edit
  them). (So it isn't shipped in the bare template; it appears after
  `/inspire:init` runs.)

## Three ownerships

Design-system tokens sit above everything. Below them, patterns and components are
**siblings** — neither depends on the other by construction — and screens compose
both:

| Owner | Owns | Never owns |
|---|---|---|
| a **component** entry | its props, and the states it renders | where it is placed |
| a **pattern** entry | its regions (named holes) and geometry | the fields its content shows |
| a **screen** | the wiring: data → components, components → regions | tokens, layouts, props |

A region is a hole, never a mirror of some component's props. That is why a
pattern's `## Regions` table says only how a hole is filled (`required` /
`optional`) and what kind of content it accepts (`data` · `dispatch` · `nav` ·
`static`).

Both catalog entries carry a `**State:**` line — `to-extract` (authored, no code
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
- **Its own `## Bindings`** — the data sources, dispatches, navigation targets and
  states it declares, each keyed screen-locally. These stand whether or not a
  pattern is named, and each row is one claim the emanation loop can cover. A
  transition a dispatch causes is that dispatch's outcome, never also a
  navigation row: one transition, one declaration, one claim.
- **Optional dependencies** — a `**Pattern:**` line naming one shared layout and a
  `**Components:**` line naming the shared components it instantiates. Peer
  dependencies, both of them: they constrain presentation and gate promotion,
  never define the screen.
- **No route.** Routes derive from `module:` + `screen:`, prefixed by the
  surface's shell. `/inspire-screens routes` renders the map; nothing stores it.

The full on-disk shape, the claim families and the old-shape catalogue are in
`.claude/skills/inspire-screens/references/format-screen.md`.

Screens realise features ([`03_features`](../03_features)) and must stay aligned
with the specs in [`04_domain`](../04_domain). Their `lifecycle:` takes the same
4-state enum as the domain layer — `draft` → `accepted` → `stable`, plus
`superseded` — walked by `/inspire-screens promote`.
