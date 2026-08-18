# Screens — create
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

## When creating a new screen

1. **Identify the feature.** Every screen references at least one feature ID from
   the module's `03_features`.
2. **Pick a pattern.** Read the `**Purpose:**` first lines of `patterns/[!_]*.md`
   (one-line-per-file) and choose the one that matches the screen's purpose. Only
   mark `**Pattern:** bespoke` if truly unique. The project's own screen
   conventions (default list pattern, header layout, tabs, toolbar rules) live in
   the patterns and `design-system.md` — follow them.
3. **Instantiate.** Describe the screen by filling the pattern's slots. Refer to
   the pattern's API in its file. Write in present state — R6 of the
   [writing contract](../../_references/writing-style.md) (never history) applies
   from the first draft.
4. **Deviations only.** Do NOT redescribe the structure the pattern already
   defines.
5. **Reference components** — link, don't re-describe: a relative wikilink into
   `05_screens/components/` (`[[{rel-to-05_screens}/components/{name}]]`).
6. **No ASCII layout diagrams** — stated once as the no-ASCII rule in
   [`inspire-screens/SKILL.md`](../SKILL.md) § Rules.
7. **No inline mock data.** Reference the data source.
8. **Register in the module's `_index.md`** — the one in the directory the screen
   lands in (nav, route map, feature coverage).
