# Screens — the live design system
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

`/inspire-screens design-system` owns `inspire_kb/01_spec/_design-system/design-system.md` and
`design-system.tokens.json` — the
project's **live design system** (typography, color + status map, density, global
layout, icons, supported viewports, the reference), seeded at install from the
default `theme.md` and `theme.tokens.json` beside them. The markdown says what each token means
and cites it by its path in braces; the JSON, in the
[W3C Design Tokens format](https://www.designtokens.org/tr/drafts/format/), holds
every value once. A value written in both is a value that will drift. Distinct from
[`/inspire-config theme`](../../inspire-config/references/theme-interview.md):
`theme.md` is the reusable default, `design-system.md` is the project's working
copy — they may diverge.

This is the only flow of this skill that writes the design system. Creating,
updating and validating a screen read its tokens and never edit them.

1. Read the current `design-system.md` and `design-system.tokens.json`. If the markdown is
   missing, seed both from the defaults (this is what install does) and say so. If
   only the token file is missing, or `## Supported viewports`, `## Icons` or
   `## Reference` is, run the `backfill` flow first
   ([`design-system-backfill.md`](design-system-backfill.md)).
2. Establish/confirm the change (a token value, the type scale, density, a new
   status key, a layout rule, the supported floor, a `generated` token or layout
   row being confirmed). A value changes in the token file; a meaning changes in the
   markdown. Present a diff; apply on approval. Confirming a token drops its
   `$extensions.inspire` marker, and a layout row carrying that value as
   `reference`, `generated` or `undecided` cites the token instead.
3. **Propagate.** A token change ripples to every screen and to the prototype —
   surface it (offer `/inspire-prototype`); screens must not hard-code values that
   belong here.
4. **One design system for every face.** There is exactly one `design-system.md`,
   in `_design-system/`, however many faces the project has. Five things a face
   might want from it, and what each gets:
   - **Extension** — vocabulary only one face uses (a data grid only the admin
     console has): a `patterns/` or `components/` entry scoped with `faces:`.
     Welcome and cheap; nothing shared is redefined, so nothing has to be
     reconciled later.
   - **Variance** — platform or context fit (mobile density, touch targets):
     **named variant axes this file defines and a face selects**, written as
     clearly-marked per-face sections *inside* it (e.g. `## Density — mobile`),
     the way mature systems handle density and dark mode. Rare, visible and
     countable — `/inspire-workspace` reports how many there are as a drift signal.
   - **Face tokens** — tokens that exist for one face only (its own illustration
     palette, its own chart series), in `_faces/{face}/{face}.tokens.json`, same
     format. They add tokens; they never redefine one `design-system.tokens.json`
     already defines.
   - **Override** — a face redefining, from its own side, what a shared token or
     component means: **no channel exists, deliberately.** Never create a
     per-face design-system file under any name. Per-consumer overrides invert
     in practice: every change becomes a design-system change *plus* an override in
     each consumer, and the agents that emanate code would have to answer "which
     spec wins?" once per face.
   - **Divergence** — a face that is genuinely its own brand: the honest form is
     a declared fork that consumes no shared design system at all, out of scope
     today; name it as such rather than approximating it with variant sections.
5. Keep token **roles** stable (primary, accent, status keys) even when values
   change — downstream skills (screens, prototype) depend on the roles, not the
   hexes. Roles are never overridden per face either: a variant axis may give a
   role a different value for one face, never a different meaning.
6. **Stamp the write.** Run `.inspire/bin/trust.sh stamp <file> --skill screens` on
   `design-system.md`; the token file carries no frontmatter and is not stamped
   ([trust-stamps](../../_references/trust-stamps.md#stamping)). Rewriting one that
   carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../../_references/trust-stamps.md#endorsement)).
