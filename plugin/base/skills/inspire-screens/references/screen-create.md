# Screens — create
> Part of [inspire-screens](../SKILL.md). Read together with [`format-screen.md`](format-screen.md), which owns the on-disk shape.

## When creating a new screen

0. **Check the ground first.** `design-system.md` names the supported viewports
   and the reference, a `*.layout.md` entry holds the face's `shell`, and the face
   has its `{face}.face.md`. A missing face goes to `/inspire-face add`; this skill
   never creates one. If anything else is missing,
   say so and run the missing piece first — the range through
   `/inspire-bootstrap design-system`, the shell as a layout entry measured per
   [`_references/ui-reference.md`](../../_references/ui-reference.md). A screen
   specified before them guesses whether a phone is in scope and what frame it sits
   in.
1. **Identify the feature.** Every screen references at least one feature ID from
   a `*.feature.md` in the module's `_features/`.
2. **Resolve the face**
   ([`_references/face-scope.md`](../../_references/face-scope.md)) and state it in
   the turn's output before writing. The file goes to
   `inspire_kb/01_spec/_faces/{face}/_screens/{slug}.screen.md`.
3. **Mint the id.** `id: {face}.{slug}`, where the slug is the file's name and is
   unique within the face. A slug already taken in the face is a different screen:
   pick another. Write `module:` and `screen:` to match the intent, not the slug —
   they give the route, under the face's shell — and set `lifecycle: draft`. The id
   is written once and never edited again.
4. **Ask what the screen is for**, in one question: *who comes to this screen,
   for which task, and what do they see first?* The answer is the `## Purpose`
   paragraph — the product's own words, as prose, never a list. It restates no
   binding and names no route: the rows below say what the screen declares,
   this says why anyone opens it, and it is what the emanating agent reads for
   intent. An answer that only rephrases the title means the screen's job is
   still unclear — ask again before writing bindings.
5. **Declare the bindings.** `## Bindings` is the screen's own semantics, and the
   part worth the interview time: what it is opened with — a record id, a
   filter, a mode flag (`### Parameters`) — which actions feed it (`### Data`),
   which it invokes and what follows each outcome (`### Dispatches`), where it
   can go (`### Navigation`), and which states it can be in (`### States`). Key
   every row screen-locally, and mark with `param \`{key}\`` each data row that
   loads by a parameter and each transition that passes one. Drop a subsection
   with nothing in it.
5b. **Check the face exposes every bound action.** Each action a `### Data` or
   `### Dispatches` row binds belongs to a bundle the face lists in `bundles:`.
   Run `.inspire/bin/face-exposure.sh` over the face. An action no bundle of the
   face exposes is a question for `/inspire-face`: add the bundle to the face, or
   the action to a bundle. An action that does not exist yet is created at draft
   through `/inspire-domain` before its row is written.
5c. **Create every missing target.** A navigation target or dispatch outcome
   naming a screen id that no `*.screen.md` declares gets its file now, from
   [`screen.template.md`](../templates/screen.template.md) at `lifecycle: draft`,
   with its identity block, its H1 and its `**Features:**` line. A link to
   something that does not exist yet requires its file.
6. **Name a pattern only if one fits.** Read the `**Purpose:**` first lines of
   every `*.pattern.md` under `inspire_kb/01_spec/` and name the pattern whose
   regions match this screen's structure, by link (`[list](../../../_design-system/patterns/list.pattern.md)`). A screen that fits none names none — omit the line rather than
   writing `bespoke`. The project's own conventions (default list layout, header
   layout, tabs, toolbar rules) live in the patterns, the layouts and
   `design-system.md`.
6b. **Name the layout that frames it.** Read the `**Purpose:**` first lines of
   every `*.layout.md` and name, by link, the frame whose `**Pattern:**` matches
   the one just named. Where several frame the same pattern, the geometry decides — a record with
   tabs and a record without them are two frames over one `detail`. Where none fits,
   create the entry from its template at `**State:** to-extract` rather than writing
   the measurements into the screen
   ([`screen-catalog.md`](screen-catalog.md) § When adding a new pattern, layout or
   component).
7. **Declare the components** the screen instantiates, on the `**Components:**`
   line, by link (`[data-table](../../../_design-system/components/data-table.component.md)`). Link, never re-describe — a
   component's props belong to its own entry. **A component this screen names and
   the catalog does not hold gets its entry now**, at `**State:** to-extract`, with
   its props, its anatomy and its states — never a name with nothing behind it.
7b. **Write `## Render`.** Capture the reference at the widths
   [`_references/ui-reference.md`](../../_references/ui-reference.md) lists, then
   give every column, field and meta value the screen shows a row: field type,
   component, treatment (tokens by path in braces, the glyph by library and name),
   alignment, and — for a table's columns — what each does at narrow widths. A
   hover-only treatment names its touch equivalent in the same cell. Shape and
   rules: [`format-screen.md`](format-screen.md) § `## Render`.
8. **Never write a route.** Not in the H1, not in a section: routes derive from
   `module:` + `screen:`. `routes` renders the map.
9. **Deviations only.** Do NOT redescribe the structure the pattern or the
   geometry the layout already defines, and write no measurement of the frame. Write in present state — R6 of the
   [writing contract](../../_references/writing-style.md) (never history) applies
   from the first draft.
10. **No ASCII layout diagrams** — stated once as the no-ASCII rule in
    [`inspire-screens/SKILL.md`](../SKILL.md) § Rules.
11. **No inline mock data.** Reference the data source through a binding.
12. **Register nothing by hand.** A screen is found by its `.screen.md` extension,
    so no index lists it. The face's `_index.md` carries navigation prose only:
    touch it when the new screen changes how a person moves through the face, and
    never add a screens table or a route column to it — a hand-copied derived value
    is a drift source.
