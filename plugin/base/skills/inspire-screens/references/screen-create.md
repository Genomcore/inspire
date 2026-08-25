# Screens — create
> Part of [inspire-screens](../SKILL.md). Read together with [`format-screen.md`](format-screen.md), which owns the on-disk shape.

## When creating a new screen

1. **Identify the feature.** Every screen references at least one feature ID from
   the module's `03_features`.
2. **Resolve the target tree** from the surface roster
   ([`_references/surface-scope.md`](../../_references/surface-scope.md)) and state
   it in the turn's output before writing.
3. **Mint the id.** `id: {module}.{screen}`, unless that id is already taken
   KB-wide — then the newcomer mints `{surface}.{module}.{screen}` and the screen
   holding the id keeps it. Write `module:` and `screen:` to match the intent, not
   the file name, and set `lifecycle: draft`. The id is written once and never
   edited again.
4. **Declare the bindings.** `## Bindings` is the screen's own semantics, and the
   part worth the interview time: which actions feed it (`### Data`), which it
   invokes and what follows each outcome (`### Dispatches`), where it can go
   (`### Navigation`), and which states it can be in (`### States`). Key every row
   screen-locally. Drop a subsection with nothing in it.
5. **Name a layout only if one fits.** Read the `**Purpose:**` first lines of
   `patterns/[!_]*.md` and name the pattern whose regions match this screen's
   structure. A screen that fits none names none — omit the line rather than
   writing `bespoke`. The project's own conventions (default list layout, header
   layout, tabs, toolbar rules) live in the patterns and `design-system.md`.
6. **Declare the components** the screen instantiates, on the `**Components:**`
   line: relative wikilinks into `05_screens/components/`
   (`[[{rel-to-05_screens}/components/{name}]]`). Link, never re-describe — a
   component's props belong to its own entry.
7. **Never write a route.** Not in the H1, not in a section: routes derive from
   `module:` + `screen:`. `routes` renders the map.
8. **Deviations only.** Do NOT redescribe the structure the pattern already
   defines. Write in present state — R6 of the
   [writing contract](../../_references/writing-style.md) (never history) applies
   from the first draft.
9. **No ASCII layout diagrams** — stated once as the no-ASCII rule in
   [`inspire-screens/SKILL.md`](../SKILL.md) § Rules.
10. **No inline mock data.** Reference the data source through a binding.
11. **Register in the module's `_index.md`** — the one in the directory the screen
    lands in. The index lists screens by **id** and title, with their feature
    coverage; it never carries a route column, because a hand-copied derived value
    is a drift source.
