# `_faces/` · what people use

A **face** is what a person uses: a set of screens with its own shell, package and
tokens. One directory per face:

```
_faces/
  {face}/
    {face}.face.md          # id, package, profiles, shell, the bundles it uses
    {face}.tokens.json      # tokens of this face only (optional)
    _index.md               # navigation prose for the face
    _adr/{slug}.adr.md      # decisions that bind this face only
    _screens/{slug}.screen.md
    _processes/{process}.process.md
```

```markdown
---
id: portal
package: apps/portal
profiles: [react]
shell: /portal
bundles: [api]
---

# Face: Customer portal
```

- **Skills:** `inspire-face` (faces and bundles), `inspire-screens` (screens).
- A face carries **no claims of its own**: its screens do.
- **A screen that depends on an action outside its face's bundles is a finding.**
- **No shared screens.** When two faces show the same thing, what they share is its
  structure: it becomes a layout or a pattern in `_design-system/`, and each face
  keeps its own screen.

## What a screen file carries

- **An identity block** — `id` · `module` · `screen` · `lifecycle`. The `id` is
  `{face}.{slug}`, minted once and never re-derived from the file's location: the
  path says where the file sits, the id says what it is. Moving a file is a move;
  changing an id makes a different screen. `module:` and `screen:` give the route.
- **A `## Purpose` paragraph** — who comes to this screen, for which task, and
  what they see first. One paragraph of prose, required: it orients a human
  reader and gives the emanating agent the screen's intent, which the feature
  links alone do not carry. It restates no binding and names no route.
- **Its own `## Bindings`** — the input parameters, data sources, dispatches,
  navigation targets and states it declares, each keyed screen-locally. A
  parameter — a record id, a filter, a mode flag — says whether it travels in the
  path or the query; the spec states it rather than leaving the code to deduce
  it. These stand whether or not a
  pattern is named, and each row is one claim INSPIRE Factory can cover. A
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
  face's shell. `/inspire-screens routes` renders the map; nothing stores it.

The full on-disk shape, the claim families and the old-shape catalogue are in
`.claude/skills/inspire-screens/references/format-screen.md`.

Screens realise features and must stay aligned with the actions they bind. Their `lifecycle:` takes the same
4-state enum as the domain layer — `draft` → `accepted` → `stable`, plus
`superseded` — walked by `/inspire-screens promote`.
