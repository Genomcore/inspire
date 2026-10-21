# Bootstrap — design-system backfill
> Part of [inspire-bootstrap](../SKILL.md). Read together with [`_references/ui-reference.md`](../../_references/ui-reference.md).

`/inspire-bootstrap design-system backfill [{reference}]` brings a design system
written before the token file up to the current shape: `design-tokens.json` beside
it, and the `## Supported viewports`, `## Icons` and `## Reference` sections in it.
`/inspire:update` runs it before `/inspire-screens backfill` whenever
`.inspire/bin/design-system-coherence.sh` reports one of them missing; an operator
can run it on its own at any time.

What the project already decided stays decided. Every value `design-system.md`
states keeps its value: it moves into the token file, and the markdown cites it.
The reference fills only what the file never said, and common sense only what the
reference does not show either.

## The run

1. **List the gaps.** Run `.inspire/bin/design-system-coherence.sh` over
   `inspire_kb/05_screens`. The missing sections and a missing token file are the
   scope; a section already present is left as it stands.
2. **Resolve the reference** per [`_references/ui-reference.md`](../../_references/ui-reference.md)
   § Which reference — passed by `/inspire:update`, named in the argument, or asked
   once with the prototype as the default.
3. **Build `design-tokens.json`** in the
   [W3C Design Tokens format](https://www.designtokens.org/tr/drafts/format/), the
   shape [`00_bootstrap/theme.tokens.json`](../../../../inspire_kb/00_bootstrap/theme.tokens.json)
   shows. Three sources, in this order, each filling only what the one before left
   open:
   1. **`design-system.md` itself.** Every colour, font, size, spacing, radius and
      density value it states becomes a token named by its role (`color.primary`,
      `size.table-row`), never by its appearance. These are decisions: no marker.
   2. **The reference.** Its stylesheet's custom properties and `@theme` block, its
      breakpoints (`min-width` rules), its icon package, and the computed values of
      what the design system never named. Mark each
      `"$extensions": { "inspire": { "source": "reference" } }`.
   3. **Common sense**, when neither holds a value a screen will need: the defaults
      of `00_bootstrap/theme.tokens.json`, adapted to the stack's UI library. Mark
      each `"$extensions": { "inspire": { "source": "generated" } }` — the validator
      counts them until someone confirms them.
   Where the reference contradicts a value `design-system.md` states, the design
   system wins and the contradiction is reported, never resolved silently.
4. **Cite instead of restating.** In `design-system.md`, replace each value that now
   lives in a token with its path in braces (`#0d9488` → `{color.primary}`), keeping
   every sentence's meaning. Add a `## Tokens` section saying the token file holds
   the values and how a path maps to a CSS custom property (`{color.primary}` →
   `--color-primary`), as the default theme's does.
5. **Write `## Supported viewports`.** The floor is a product decision: take the one
   `/inspire:update` asked for, or ask — phone in scope, tablet up, or laptop up.
   The ranges above it are the reference's breakpoints, found by sweeping the width,
   cited from the `breakpoint` tokens; with no reference, the defaults' ranges,
   marked generated. Say that the tablet range takes touch input when it is in
   scope.
6. **Write `## Icons`.** The library the reference installs (its package manifest)
   or the stack profile names, the sizes and the stroke it draws them at, as tokens;
   and the rule that a spec names a glyph by its library name.
7. **Write `## Reference`** as [`_references/ui-reference.md`](../../_references/ui-reference.md)
   shows: what was measured, when, at which widths — or `none — values generated on
   {date}`.
8. **Stamp and check.** `.inspire/bin/trust.sh stamp inspire_kb/05_screens/design-system.md
   --skill bootstrap`; the token file carries no frontmatter and is not stamped.
   Re-run `design-system-coherence.sh`: it should report only the counted generated
   tokens.
9. **Report** the tokens by source (stated, reference, generated), every
   contradiction between the reference and the design system, and — when anything
   was generated — the advisory of [`_references/ui-reference.md`](../../_references/ui-reference.md).

Confirming a generated or reference token later is an ordinary `design-system` edit:
set its value, drop its `$extensions.inspire` marker, and, where a layout row carried
that value as `reference` or `generated`, cite the token instead.
