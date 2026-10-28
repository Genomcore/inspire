# Layouts

The **page frames**: what a screen sits inside, measured. One entry per frame,
suite-wide, beside [`patterns/`](../patterns) and [`components/`](../components).

A layout and a pattern describe the same screen from two sides, and the split keeps
either one small:

| Tier | Owns | Answers |
|---|---|---|
| [`patterns/`](../patterns) | regions | which holes a screen fills, and what kind of content each accepts |
| `layouts/` | geometry | where those holes sit, at what size, in what order, at every supported width |
| [`components/`](../components) | props | what goes in a hole |
| [`design-system.md`](../design-system.md) · `design-tokens.json` | tokens | the values a layout cites |

A screen names both: `**Pattern:** [[../patterns/list]]` and
`**Layout:** [[../layouts/collection]]`. The surface **shell** — the sidebar, the
bars, every persistent control — is a layout entry too, `shell.md`, that no screen
names because it frames every route.

A layout at `**State:** to-extract` is a unit INSPIRE Factory builds, like a
pattern or a component: each `## Geometry` and `## Breakpoints` row is a claim its
tests cite, and a screen waits for every layout its `**Layout:**` line names. Every
screen also waits for `shell`, whose contract adds one claim more — the application
mounts it around every route.

## The Source column

Every `## Geometry` and `## Breakpoints` row says where its value comes from, and
the vocabulary is closed:

| Source | Means |
|---|---|
| `design-system.md §…` | the design system fixes it; cite the section, never a different number |
| `design-tokens.json` | the Value cell cites a token — `` `{spacing.6}` `` |
| `reference` | measured from the reference [`design-system.md`](../design-system.md) § Reference names — the prototype by default; a question for the design system, not yet a decision |
| `generated` | no reference held it, so it was proposed by common sense; nobody has confirmed it |
| `undecided` | two adopters disagree, or the reference breaks there, and nothing resolves it |
| `as {layout}` | this row's geometry is another entry's, wholesale |

`prototype`, the word an earlier draft of this tier used, reads as `reference`.

`screen-presentation.sh` counts the `generated` and `undecided` rows of every entry
on each run. Confirming one is a design-system decision, so it runs through
`/inspire-bootstrap design-system`, which moves the value into a token and turns the
row's Source into `design-tokens.json`.

## The Breakpoints table

Every entry carries a `## Breakpoints` table after `## Geometry`: per width range,
which region changes and how — width, columns, stacking, visibility, scroll. The
ranges are the ones [`design-system.md`](../design-system.md) § Supported viewports
names. A row holding at every range reads `every supported width`.

Below the supported floor nothing is designed. Clipping, overflow or overlap the
reference shows at any width is a gap: the entry's `## Notes` names the width and the
elements, and the row proposing a behaviour carries `undecided`.
