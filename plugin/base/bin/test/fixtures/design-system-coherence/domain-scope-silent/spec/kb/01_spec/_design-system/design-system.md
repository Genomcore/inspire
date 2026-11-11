---
kind: bootstrap-theme
status: template         # the default theme template; copied to 05_screens/design-system.md at install
---

# Design system (theme) — default template

The **default design-system template**: theme, typography, color, density,
layout, icons and the supported viewports. This is a *seed*, not the live source
of truth — `materialize.sh` copies it to
[`05_screens/design-system.md`](../05_screens), and its token values
[`theme.tokens.json`](theme.tokens.json) to `05_screens/design-tokens.json`,
during `/inspire:init`. Those two files become the project's working design
system. From then on edit the live ones with `/inspire-bootstrap design-system`;
re-seed this default with `/inspire-bootstrap theme`.

> **Default**, abstracted from the OpenBIMS mockup's CSS (`@theme` tokens +
> design-system spec). Swap the values for your brand — the token *roles* below are
> what the skills rely on.

## Tokens

Every value lives in exactly one place: the token file beside this one, in the
[W3C Design Tokens format](https://www.designtokens.org/tr/drafts/format/). This
file says what each token **means** and when to use it, and cites it by its path
in braces — `{color.primary}` — never by its value. A cited path that the token
file does not define is a finding (`design-tokens.sh`).

A token's CSS custom property is its path joined with hyphens: `{color.primary}`
is `--color-primary`, `{spacing.4}` is `--spacing-4`. A Tailwind v4 `@theme`
block emitting those properties gives the matching utilities (`bg-primary`,
`p-4`), so the prototype and the production code read the same names.

## Theme mode

- **Light mode** as the default and only supported theme in v1.
- Page ground `{color.background}`; recessed regions `{color.surface}`; cards
  `{color.card}` with a `{color.border}` edge and `{radius.lg}` corners. Text:
  primary `{color.text.primary}`, secondary `{color.text.secondary}`, tertiary
  `{color.text.tertiary}`. Dividers `{color.border}`. Hover `{color.hover}`.

## Typography

- **Sans (body):** `{font.family.sans}`.
- **Mono (IDs, code, endpoints, paths):** `{font.family.mono}`.
- **Scale:** page title `{font.size.xl}` at `{font.weight.semibold}`; page
  subtitle `{font.size.sm}` in `{color.text.secondary}`; section header
  `{font.size.xs}` uppercase, wide tracking, `{font.weight.medium}`, in
  `{color.text.tertiary}`; body `{font.size.sm}`; meta `{font.size.xs}`.

## Color

| Role | Token |
|------|-------|
| Primary — actions, active state | `{color.primary}`, `{color.primary-hover}` on hover |
| AI / accent — assistant, agents | `{color.accent}` |
| Neutral grounds and text | `{color.background}` · `{color.surface}` · `{color.card}` · `{color.text.primary}` |

### Canonical status map

The status keys a status indicator supports; anything outside is a candidate to
add or a symptom of local over-specialization. Each tone carries a dot, a ground
and a foreground: `{color.status.success.dot}`, `{color.status.success.bg}`,
`{color.status.success.fg}`.

| Keys | Tone |
|------|------|
| `active` · `healthy` · `running` · `ready` · `passed` | `{color.status.success}` |
| `building` · `pending` · `indexing` · `syncing` · `in-progress` | `{color.status.progress}`, its dot pulsing |
| `warn` · `degraded` · `draft` · `expiring` · `stale` | `{color.status.warning}` |
| `error` · `failed` · `down` · `expired` · `revoked` | `{color.status.danger}` |
| `idle` · `disabled` · `archived` · `deprecated` · `resolved` | `{color.status.idle}` |
| `ai` · `agent` · `assistant` | `{color.status.ai}` |

## Density

- Table rows `{size.table-row}` (compact, Linear/Airtable feel); sidebar items
  `{size.sidebar-item}`.
- Card padding `{spacing.4}` (or `{spacing.6}` for primary content); section gap
  `{spacing.6}`; list-item gap `{spacing.3}`.

## Global layout

- Top bar `{size.top-bar}` high with a `{color.border}` bottom edge (launcher and
  logo left; search ⌘K and avatar right).
- Each page frame — the shell and the frame every pattern sits in — is a
  [`05_screens/layouts/`](../05_screens/layouts) entry that cites these tokens;
  screens don't redefine it.

## Icons

- **Library:** [lucide](https://lucide.dev). A spec names a glyph by its lucide
  name (`lucide-folder`), never as "an icon".
- **Size:** `{icon.size.sm}` inline and in buttons, `{icon.size.md}` in
  navigation.
- **Stroke:** `{icon.stroke}`.

## Supported viewports

The product works at every width from `{viewport.min}` up. Below it nothing is
specified, and what the product does there is recorded as a gap, never designed.

A range runs from its own breakpoint up to the next one; `wide` has no upper end.

| Range | From | Tailwind prefix |
|---|---|---|
| tablet | `{breakpoint.md}` | `md:` |
| laptop | `{breakpoint.lg}` | `lg:` |
| desktop | `{breakpoint.xl}` | `xl:` |
| wide | `{breakpoint.2xl}` | `2xl:` |

The tablet range takes touch input, so every hover-only affordance names its
touch equivalent in its component entry.

## Reference

What the screen layer is measured from. Every `reference` row in a
[`layouts/`](../05_screens/layouts) entry was measured here.

- **Reference:** none yet
- **Captured:** —
- **Widths:** —
