# Bootstrap — theme interview
> Part of [inspire-bootstrap](../SKILL.md). Read when the entry's index routes here.

## Subcommand: theme

Define or update `theme.md` — the design system. The token **roles** (primary,
accent, status map, typography, density) are what downstream skills rely on; the
values are yours to set.

1. Read the current `theme.md`.
2. Establish/confirm: theme mode, typography (sans + mono, scale), the color tokens
   (primary, accent, success/warn/error/info/neutral) + the canonical status map,
   density, and global layout tokens.
3. Present a diff and apply on approval.
4. **`theme.md` is the default template, not the live design system.** At install
   it is copied to `05_screens/design-system.md`, which becomes the project's
   working design system. So:
   - Edit `theme.md` here to change the **reusable default** (e.g. before
     bootstrapping, or to keep the default in sync).
   - To change the **project's live** design system, use the `design-system`
     subcommand ([`../SKILL.md`](../SKILL.md) § Subcommand: design-system) — that's
     the source of truth once seeded.
   - Offer to (re)seed `05_screens/design-system.md` from `theme.md` if it doesn't
     exist yet.

### Abstracting a theme from a mockup's CSS

A fast way to seed `theme.md` is to **derive it from an existing mockup's CSS**:

1. Read the mockup's theme source — the CSS custom properties / `@theme` block
   (fonts, color variables), plus any design-system notes.
2. Lift the concrete values (font families, the primary/accent hexes, the status
   colors, the neutral scale) into the token table.
3. Generalize product-specific names into **roles** (e.g. a brand "assistant"
   color → the `accent` / `ai` role); keep the values.
4. Fill density + layout from how the mockup actually spaces things.

