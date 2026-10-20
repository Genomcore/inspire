# Screens — backfill
> Part of [inspire-screens](../SKILL.md). Read together with [`_references/ui-reference.md`](../../_references/ui-reference.md), [`format-screen.md`](format-screen.md) and [`screen-catalog.md`](screen-catalog.md).

`/inspire-screens backfill [{reference}]` brings a vault written before the layouts
tier and `## Render` up to the current presentation shape in one run: the frames,
the breakpoints, how every value is drawn, and the component entries those name.
`/inspire:update` runs it after `/inspire-bootstrap design-system backfill` whenever
the vault has a presentation gap; an operator can run it on its own at any time.

It fills gaps and nothing else. It never touches an id, a `lifecycle:`, a binding,
`## Purpose` or a feature link, so it re-emanates nothing, and it may run on a
`stable` screen because everything it writes is the presentation half
([`screen-update.md`](screen-update.md) § Stable screens block).

## Before it starts

1. **The design system is ready.** `design-system.md` carries `## Supported
   viewports`, `## Icons` and `## Reference`, and `design-tokens.json` exists. If
   `.inspire/bin/design-system-coherence.sh` reports any of them missing, run
   `/inspire-bootstrap design-system backfill` first: every row this flow writes
   cites a token or the reference that file names.
2. **The reference is resolved** per [`_references/ui-reference.md`](../../_references/ui-reference.md)
   § Which reference. When `/inspire:update` invokes this flow it passes the
   operator's answer; otherwise the argument names one, or the flow asks once with
   the prototype as the default.
3. **The gaps are listed.** Run `.inspire/bin/screen-presentation.sh` over
   `inspire_kb/05_screens` and group what it reports: frames missing, screens with
   no `**Layout:**`, screens with no `## Render`, tables with no `Narrow`, components
   named with no entry, hover with no touch path. That list is the whole scope of
   the run; a screen it does not name is left alone.

## The run

1. **Capture.** With a reference: start it, derive the routes
   ([`screen-routes.md`](screen-routes.md)), and capture every route the gap list
   names at each width [`_references/ui-reference.md`](../../_references/ui-reference.md)
   lists, sweeping each range for its breakpoints. Without one, skip the capture:
   every value below is then generated, from the tokens first, the framework
   profile next and the stack's UI library defaults last.
2. **The shell first.** One `layouts/shell.md` per distinct chrome — a surface whose
   chrome differs takes its own, scoped by `surfaces:`. It frames every route, so
   every other frame is measured inside it.
3. **Then one frame per distinct geometry.** Group the screens by the pattern they
   name and by what the capture measured: two screens over one `detail`, one with
   tabs and one without, are two frames. Reuse an existing entry wherever its rows
   hold; write a new one from
   [`layout-entry.md.template`](../templates/layout-entry.md.template) otherwise,
   even for a single adopter — the alternative is a measurement in a screen. Name
   each frame for its shape (`collection`, `record-tabbed`), never for a screen.
4. **Source every row** by the vocabulary the template fixes:
   - a value equal to a token → the token's path in braces, Source
     `design-tokens.json`;
   - a value `design-system.md` states → its section, Source `design-system.md §…`;
   - any other measured value → Source `reference`;
   - a value no reference held → Source `generated`;
   - clipping, overflow or overlap at a width → a gap in `## Notes` naming the width
     and the elements, and the row proposing what should happen instead → Source
     `undecided`.
   A row already sourced `design-system.md` or `design-tokens.json` is a decision:
   leave it as it stands.
5. **Each screen in the gap list:**
   - add the `**Layout:**` line naming its frame;
   - write `## Render` — one H3 per region of its pattern, one row per column,
     field, meta value or control the capture shows (or, when generating, per data
     binding and the values the design system's field types imply), with the
     component, the treatment (tokens by path, the glyph by library and name), the
     alignment and, for a table's columns, `Narrow`;
   - record what breaks at a width as a `gap` drift item under
     `## Current prototype`.
6. **Each component a Render row names and the catalog lacks:** write its entry at
   `**State:** to-extract` from
   [`component-entry.md.template`](../templates/component-entry.md.template) — props
   from what the screens pass it, its states, every hover state with its touch
   equivalent.
7. **Each hover finding** on an existing entry or screen: name the tap or
   long-press path. Where the reference shows none, write the one the platform's
   convention gives and say so in the report.

## Closing the run

1. **Stamp** every file written: `.inspire/bin/trust.sh stamp <file> --skill
   screens` ([trust-stamps](../../_references/trust-stamps.md#stamping)). A file
   carrying `endorsed:` is disclosed before it is rewritten, and its rewrite waits
   for the operator's yes.
2. **Re-run the mechanical half**: `screen-presentation.sh`,
   `design-system-coherence.sh`, `screen-coherence.sh` and `sections-present.sh`
   over `inspire_kb/05_screens`. The first two should report only the counted
   `generated` and `undecided` rows; anything else is this run's to fix before it
   ends. The last two must report nothing they did not report before the run.
3. **Report**, in this order:
   - the files written, grouped as layouts, screens and components;
   - the rows by Source: how many cite a token or the design system, how many are
     `reference`, how many `generated`, how many `undecided`;
   - every gap found, by width;
   - **when anything was generated, the advisory** of
     [`_references/ui-reference.md`](../../_references/ui-reference.md) § Which
     reference: how many values, in which files, decided by nobody, and that
     `/inspire-bootstrap design-system` confirms them.
4. **No propagation question.** The run made the spec catch up with the reference;
   the prototype has nothing to catch up with. A run that generated values asks
   instead whether to rebuild the prototype from them (`/inspire-prototype`).

The run is idempotent: run again, it finds only what is still missing.
