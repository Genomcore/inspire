# Screens — checks
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

## Checks

1. **Pattern exists.** The `**Pattern:**` link resolves.
2. **Feature IDs exist.** All referenced features exist in the module's
   `03_features`.
3. **No redundant structure.** The screen doesn't redescribe what the pattern
   already specifies.
4. **Component references resolve.** Every component wikilink resolves to a file in
   `05_screens/components/`, whatever its `../` depth.
5. **Data reference is valid.**
6. **No ASCII layout diagrams** — checked against the no-ASCII rule in
   [`inspire-screens/SKILL.md`](../SKILL.md) § Rules.
7. **No inline mock data.**
8. **The writing contract holds** — R1–R6 of
   [`_references/writing-style.md`](../../_references/writing-style.md), R6 (historical
   language) first among them.
9. **Route follows convention** — the route takes the form the Route-convention rule
   in [`inspire-screens/SKILL.md`](../SKILL.md) § Rules gives for the suite's
   UI-surface count, and it matches the screen's own path.
10. **Live prototype check.** When the prototype can be run, navigate every route
    the screen describes and compare it against the spec — see the live prototype
    browse in [`screen-validate.md`](screen-validate.md).
