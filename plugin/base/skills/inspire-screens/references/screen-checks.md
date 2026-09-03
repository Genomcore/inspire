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
2. **The purpose is stated.** `## Purpose` is there and carries one paragraph of
   prose: who comes to this screen, for which task, what they see first.
   Presence and emptiness are mechanical; whether the paragraph tells a reader
   something the title did not is judgment. A purpose that re-lists the bindings,
   or that names a route, is a finding on this screen.
   *(mechanical for presence, judgment for the rest)*
3. **No route is authored.** The H1 is a title; no section carries a path.
   *(mechanical, warning)*
4. **Bindings resolve internally.** Every dispatch outcome names a declared state
   key, a declared data key, or a screen id; every state's `When` references a
   declared data key, dispatch key, or a deviation; keys are unique per
   subsection. *(mechanical)*
5. **Bindings resolve outward.** Every action wikilink resolves to a descriptor in
   `04_domain`; every navigation target resolves to a screen id.
   *(mechanical, via `wikilinks-resolve`)*
6. **The pattern join holds.** Where `**Pattern:**` is named, every required
   region that accepts a binding kind finds one — a `list` layout with no data
   binding is a finding. *(mechanical)*
7. **Feature IDs exist.** All referenced features exist in the module's
   `03_features`.
8. **Component references resolve.** Every component wikilink resolves to a file in
   `05_screens/components/`, whatever its `../` depth — and a screen at
   `lifecycle: stable` declares no component still at `**State:** to-extract`.
   *(mechanical)*
9. **No redundant structure.** The screen doesn't redescribe what the pattern
   already specifies, and no binding table restates a component's props.
10. **No ASCII layout diagrams** — checked against the no-ASCII rule in
    [`inspire-screens/SKILL.md`](../SKILL.md) § Rules.
11. **No inline mock data.**
12. **The writing contract holds** — R1–R6 of
    [`_references/writing-style.md`](../../_references/writing-style.md), R6 (historical
    language) first among them. `## Purpose` is normative prose for
    `prose-style.sh`: every rule that binds to a screen's body sections reaches
    it, exactly as it reaches `## Notes`.
13. **Live prototype check.** When the prototype can be run, navigate every route
    the screen derives and compare it against the spec — see the live prototype
    browse in [`screen-validate.md`](screen-validate.md).

## Old-shape screens

A screen with no `id:` in frontmatter predates the identity block. It is not a
defect to report and walk away from: offer the migration, one screen at a time —
mint the id, move the `## Instantiation` declarations into keyed `## Bindings`
rows, drop the route from the H1, ask for the `## Purpose` paragraph (an
old-shape file carries no sentence to convert into one), set `lifecycle: draft`.
`update` is where that conversion runs, step by step
([`screen-update.md`](screen-update.md)). The old-shape catalogue
is [`format-screen.md`](format-screen.md) § Old shape → new shape; until the file
carries an id, every finding on it stays a warning.
