# Screens — checks
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

The mechanical half of these checks is
`.inspire/bin/screen-coherence.sh` plus the screen block of
`.inspire/bin/sections-present.sh` — run them rather than re-deriving them by eye.
What follows is the whole list, mechanical and judgment alike.

## Checks

1. **Identity holds.** `id` · `module` · `screen` · `lifecycle` are present; the
   id is unique KB-wide and shaped `{module}.{screen}` or
   `{surface}.{module}.{screen}`; `module:` matches the path's module directory.
   *(mechanical)*
2. **No route is authored.** The H1 is a title; no section carries a path.
   *(mechanical, warning)*
3. **Bindings resolve internally.** Every dispatch outcome names a declared state
   key, a declared data key, or a screen id; every state's `When` references a
   declared data key, dispatch key, or a deviation; keys are unique per
   subsection. *(mechanical)*
4. **Bindings resolve outward.** Every action wikilink resolves to a descriptor in
   `04_domain`; every navigation target resolves to a screen id.
   *(mechanical, via `wikilinks-resolve`)*
5. **The pattern join holds.** Where `**Pattern:**` is named, every required
   region that accepts a binding kind finds one — a `list` layout with no data
   binding is a finding. *(mechanical)*
6. **Feature IDs exist.** All referenced features exist in the module's
   `03_features`.
7. **Component references resolve.** Every component wikilink resolves to a file in
   `05_screens/components/`, whatever its `../` depth — and a screen at
   `lifecycle: stable` declares no component still at `**State:** to-extract`.
   *(mechanical)*
8. **No redundant structure.** The screen doesn't redescribe what the pattern
   already specifies, and no binding table restates a component's props.
9. **No ASCII layout diagrams** — checked against the no-ASCII rule in
   [`inspire-screens/SKILL.md`](../SKILL.md) § Rules.
10. **No inline mock data.**
11. **The writing contract holds** — R1–R6 of
    [`_references/writing-style.md`](../../_references/writing-style.md), R6 (historical
    language) first among them.
12. **Live prototype check.** When the prototype can be run, navigate every route
    the screen derives and compare it against the spec — see the live prototype
    browse in [`screen-validate.md`](screen-validate.md).

## Old-shape screens

A screen with no `id:` in frontmatter predates the identity block. It is not a
defect to report and walk away from: offer the migration, one screen at a time —
mint the id, move the `## Instantiation` declarations into keyed `## Bindings`
rows, drop the route from the H1, set `lifecycle: draft`. The old-shape catalogue
is [`format-screen.md`](format-screen.md) § Old shape → new shape; until the file
carries an id, every finding on it stays a warning.
