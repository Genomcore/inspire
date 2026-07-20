---
name: inspire-bootstrap
description: "Configure the project's foundation — the tech stack and the design system (theme) in .inspire_kb/00_bootstrap. Use when bootstrapping a new project, changing a stack choice, or defining/updating the theme (including abstracting it from a mockup's CSS)."
---

# /inspire_bootstrap — Foundation (stack + theme)

## Scope

This skill owns the **bootstrap layer** —
[`.inspire_kb/00_bootstrap/`](../../.inspire_kb/00_bootstrap):

- `stack.md` — the **tech stack** the product is built with.
- `theme.md` — the **design system / theme** (fonts, color palette + status map,
  density, layout tokens).

These are the foundation every other layer reads: specs ([`04_specs`](../../.inspire_kb/04_specs)),
UISpecs ([`05_ui`](../../.inspire_kb/05_ui)), the prototype ([`/prototype`](../../prototype))
and production code ([`/source`](../../source)) all build on what is declared here.
The template seeds both with a sensible default (the OpenBIMS reference stack +
theme); a new project reconfigures them here.

## Invocation

- `/inspire_bootstrap init` — first-time setup: establish `stack.md` + `theme.md`
- `/inspire_bootstrap stack` — define / update the tech stack
- `/inspire_bootstrap theme` — define / update the design system (theme)
- `/inspire_bootstrap review` — check the artifacts exist and stay coherent

## Subcommand: init

Bootstrap a project's foundation. Offer two paths, conversationally:

1. **Keep the default** — the seeded stack + theme are a fine starting point; edit
   later as choices firm up. Fastest.
2. **Configure now** — run the `stack` then `theme` flows below to tailor both.

Confirm the outcome and point the operator at the next layer (usually
`/inspire_module create` for the first module).

## Subcommand: stack

Define or update `stack.md` — the official application stack.

1. Read the current `stack.md`.
2. Interview / confirm each layer: language, frontend (UI library, build, styling,
   component layer, icons, charts, routing), backend runtime + framework, data /
   messaging / scheduling, function execution, the prototype's mock-data engine,
   and shared tooling.
3. Present a diff and apply on approval.
4. **A load-bearing change is an ADR.** Adding a tool is a plain edit here;
   replacing a load-bearing choice (a framework, the runtime, the primary DB) must
   be recorded as an ADR in [`01_adr`](../../.inspire_kb/01_adr) — surface that and
   offer to chain `/inspire_workspace adr create`.

## Subcommand: theme

Define or update `theme.md` — the design system. The token **roles** (primary,
accent, status map, typography, density) are what downstream skills rely on; the
values are yours to set.

1. Read the current `theme.md`.
2. Establish/confirm: theme mode, typography (sans + mono, scale), the color tokens
   (primary, accent, success/warn/error/info/neutral) + the canonical status map,
   density, and global layout tokens.
3. Present a diff and apply on approval.
4. `theme.md` is the **source of truth** for the design system. The
   `05_ui/design-system.md` and the prototype must not redefine these tokens — if a
   token changes, surface the propagation to `/inspire_ui` and `/inspire_prototype`.

### Abstracting a theme from a mockup's CSS

A fast way to seed `theme.md` is to **derive it from an existing mockup's CSS**:

1. Read the mockup's theme source — the CSS custom properties / `@theme` block
   (fonts, color variables), plus any design-system notes.
2. Lift the concrete values (font families, the primary/accent hexes, the status
   colors, the neutral scale) into the token table.
3. Generalize product-specific names into **roles** (e.g. a brand "assistant"
   color → the `accent` / `ai` role); keep the values.
4. Fill density + layout from how the mockup actually spaces things.

## Subcommand: review

- `stack.md` and `theme.md` exist and parse.
- No load-bearing stack choice contradicts an accepted ADR in `01_adr`.
- The theme tokens the UISpecs (`05_ui/design-system.md`) and the prototype use
  trace back to `theme.md` — flag divergence as drift.
- Flag any layer/token still on the seeded default when the project has clearly
  moved past it.

## Rules

1. **`review` is read-only.** `init` / `stack` / `theme` present a plan before
   writing.
2. **Bootstrap is upstream of everything.** A change here can ripple to specs,
   UISpecs, the prototype and production code — surface the propagation; don't edit
   those layers silently.
3. **Load-bearing choices are ADRs.** Replacing a framework or the primary color is
   an architectural decision recorded in `01_adr` (update to add, supersede to
   replace), kept in sync with `stack.md` / `theme.md`.
4. **Roles over values.** Downstream skills depend on token *roles* (primary,
   accent, status keys) — keep them stable even when values change.
5. **Consult the task tracker** (`/inspire_workspace task list`) for tracked
   bootstrap work.

## Related skills

- `/inspire_ui` — instantiates the theme's tokens into patterns/components.
- `/inspire_prototype` — builds the horizontal prototype on this stack + theme.
- `/inspire_workspace adr create` — record load-bearing stack/theme decisions.
