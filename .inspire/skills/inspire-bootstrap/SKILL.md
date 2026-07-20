---
name: inspire-bootstrap
description: "Configure the project's foundation — the output language, tech stack and its shape (frontend / backend / monorepo, web / mobile, database provisioning), and design system (theme) in .inspire_kb/00_bootstrap, plus the project's root README. Use when bootstrapping a new project, setting the language artifacts are written in, choosing the project shape, changing a stack choice, or defining/updating the theme (including abstracting it from a mockup's CSS)."
---

# /inspire_bootstrap — Foundation (language + stack + theme)

## Scope

This skill owns the **bootstrap layer** —
[`.inspire_kb/00_bootstrap/`](../../.inspire_kb/00_bootstrap):

- `project.md` — **project conventions**, chiefly `output_language`: the single
  language every skill writes its artifacts in (default English).
- `stack.md` — the **tech stack** the product is built with, and its **shape**
  (frontend / backend / monorepo · web / mobile · database provisioning).
- `theme.md` — the **design system / theme** (fonts, color palette + status map,
  density, layout tokens).

These are the foundation every other layer reads: specs ([`04_domain`](../../.inspire_kb/04_domain)),
screen specs ([`05_screens`](../../.inspire_kb/05_screens)), the prototype ([`/prototype`](../../prototype))
and production code ([`/source`](../../source)) all build on what is declared here.
The template seeds all three with a sensible default (English + the OpenBIMS
reference stack + theme); a new project reconfigures them here.

At first-time setup this skill also establishes **project identity** — the root
`README.md`. The template's methodology README is removed at instantiation
(`install.sh`), so `init` creates the project's own (see the `readme` subcommand).

## Invocation

- `/inspire_bootstrap init` — first-time setup: establish `project.md` (language),
  `stack.md` + `theme.md`, and create the project's root `README.md`
- `/inspire_bootstrap language` — set the output language artifacts are written in
- `/inspire_bootstrap stack` — define / update the tech stack
- `/inspire_bootstrap theme` — define / update the design system (theme)
- `/inspire_bootstrap readme` — create / update the project's root `README.md`
- `/inspire_bootstrap review` — check the artifacts exist and stay coherent

## Subcommand: init

Bootstrap a project's foundation. **Always show the seeded default and ask the
operator whether to keep it or change it** — never assume they want the default.
The default is a starting point, not a mandate; most projects will want to tailor
at least the stack.

1. **Set the output language** first (it governs everything written afterward) by
   running the `language` flow. Default English; confirm or change.
2. **Establish the shape, then the stack** (`stack.md`) by running the `stack`
   flow. It first asks the **shape** (frontend / backend / monorepo · web / mobile ·
   database provisioning + local dev DB), then confirms the applicable layers. Call
   out that the default is deliberately lean (a full-stack web monorepo: TypeScript
   + React/Vite/Tailwind + a Node/NestJS backend + PostgreSQL); anything heavier
   (message buses, job queues, function sidecars, a specific mock-data engine) is a
   project choice, not a default.
3. **Show the default theme** (`theme.md`) and ask the same. If they want changes,
   run the `theme` flow (or derive it from a mockup's CSS).
4. **Create the project's root `README.md`** by running the `readme` flow. At
   instantiation `install.sh` removes the template's own methodology README, so a
   fresh project has none — this is where it gets one.
5. **Wire the local git remote (optional).** Run `git remote -v`; show the current
   `origin`. Ask — optional, skippable — for the remote the project should push to.
   If they give one, wire it on an **explicit yes** (`git remote add origin <url>`,
   or `git remote set-url origin <url>` if one exists); never change git config
   silently. This is purely local git setup — the remote is **not** written into
   the README or any artifact.

Confirm the outcome and point the operator at the next layer (usually
`/inspire_module create` for the first module).

## Subcommand: stack

Define or update `stack.md` — the official application stack, including its
`## Shape`.

1. Read the current `stack.md`.
2. **Establish the shape first — it frames which layers apply.** Ask one simple
   choice at a time (defaults from `stack.md` in brackets); write it to the
   `## Shape` section:
   1. **Platform** — is the product **[1] frontend-only**, **[2] backend-only** (an
      API / service), **[3] a monorepo with frontend + backend**, or **[4] not sure
      yet**? On *not sure*, record the platform as `undecided`, proceed with the
      leanest reasonable assumption, and flag it to revisit once the prototype
      clarifies — never force the choice.
   2. **If there is a frontend** — **[1] web-only**, **[2] mobile-only**, or
      **[3] web + mobile**? Mobile adds a mobile UI stack (e.g. React Native /
      Expo); web + mobile means both, ideally sharing types/logic.
   3. **If there is a backend** — two questions:
      - **Database:** do we **deploy** a database as part of the platform, or
        **connect to an existing external** one? If connecting, record it as
        external (connection config only, no provisioning); if deploying, it's the
        *Data* layer.
      - **Local dev database:** want one for local development? If yes, **suggest
        running it via Docker** — a container like any other local service — and
        fall back to deploying it directly on the host only when Docker isn't
        available. If no, note that dev runs against a shared/remote DB.
3. Interview / confirm each **applicable** layer, skipping what the shape excludes
   (no backend/data questions for a frontend-only product, no frontend questions
   for a backend-only service): language; frontend (UI library, build, styling,
   component layer, icons, charts, routing — plus the mobile stack if mobile is in
   scope); backend runtime + framework; data / messaging / scheduling; function
   execution; the prototype's mock-data engine; and shared tooling.
4. Present a diff — the `## Shape` section plus the layers — and apply on approval.
5. **A load-bearing change is an ADR.** Adding a tool is a plain edit here;
   replacing a load-bearing choice (a framework, the runtime, the primary DB) — or
   **changing the shape** (adding a backend, adding mobile, switching from a
   deployed database to an external one) — must be recorded as an ADR in
   [`01_adr`](../../.inspire_kb/01_adr) — surface that and offer to chain
   `/inspire_workspace adr create`.

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
   - To change the **project's live** design system, use
     `/inspire_screens design-system` — that's the source of truth once seeded.
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

## Subcommand: readme

Create (or update) the **project's root `README.md`** — the product's own front
door, not INSPIRE's. Keep it **easy and optional**: propose good defaults, ask in
one short pass, and let the operator skip any field with Enter. Write it in the
project's `output_language` (default English).

1. **Gather sensible defaults first** (don't make the operator supply what you can
   infer):
   - **Title** — default to the repo/directory name, humanized (e.g. `my-app` →
     "My App"). Confirm or override.
   - **Description** — ask for a one-line description (optional; skippable).
2. **Ask them together, all optional.** Present both prefilled and invite edits in
   a single exchange — e.g. "Title [My App] · Description [ ] — keep, or change?".
   Never block: Enter accepts the defaults, blanks are fine.
3. **If a `README.md` already exists** that is *not* the template's methodology
   README (the template one is removed at install), show a diff and confirm before
   overwriting — treat it as the operator's file.
4. **Write a lean project README** from the answers. Keep it minimal — this is a
   starting point the operator will grow:

   ```markdown
   # {Title}

   {Description — omit this line if skipped}

   ## Development

   Built with the [INSPIRE](https://inspire.openbims.dev) methodology. Project
   intent and specs live in [`.inspire_kb/`](.inspire_kb/); the guardrail runtime
   and agent skills are in `.claude/` (see [`CLAUDE.md`](CLAUDE.md)).
   ```

   Drop any section whose input was skipped. If everything was skipped, write just
   the title heading plus the `## Development` note.
5. **The git remote is not a README field.** It is asked (optional) to wire local
   git at `init`, not stored here — don't add a "Repository" line.

## Subcommand: language

Set the project's **output language** — the single language every INSPIRE skill
writes its KB artifacts in (`project.md` frontmatter `output_language`; default
`en`). See [`_references/output-language.md`](../_references/output-language.md).

1. Read the current `output_language` from
   [`00_bootstrap/project.md`](../../.inspire_kb/00_bootstrap/project.md).
2. Ask for the language (an ISO 639-1 code or a plain name; default English). Make
   clear what it does and does **not** govern:
   - **Governs:** every KB artifact — specs, features, ADRs, screen specs,
     prototype learnings, the tracker, bootstrap docs and the project README.
   - **Does not govern:** the conversation language (talk to Claude in anything) or
     the product's own i18n (the shipped UI can be multilingual). The KB stays
     single-language for a stable, diffable shared context.
3. Present the change and write `output_language` to `project.md` on approval.
   Changing it does **not** retranslate existing artifacts — say so, and offer to
   translate on request. Machine-read tokens (frontmatter keys/values, wikilink
   slugs, filenames, IDs) are never translated regardless.

## Subcommand: review

- `project.md`, `stack.md` and `theme.md` exist and parse.
- `project.md` declares a valid `output_language`. Flag if missing/empty.
- `stack.md` has a `## Shape` section, and the declared layers are coherent with
  it (no frontend stack on a backend-only product; a data layer iff the shape
  deploys a database; a mobile stack iff mobile is in scope). Flag a `shape:
  undecided` platform as still-open, to revisit.
- The project's root `README.md` exists and is the project's own (not the
  template's methodology README, which install removes). Flag if missing and offer
  to run the `readme` flow.
- No load-bearing stack choice contradicts an accepted ADR in `01_adr`.
- `05_screens/design-system.md` exists (it should have been seeded from `theme.md`
  at install); flag if missing. It is expected to **diverge** from the default
  `theme.md` as the project evolves — divergence is not drift.
- Flag any stack layer still on the seeded default when the project has clearly
  moved past it.

## Rules

> **Output language.** Write every artifact — `stack.md`, `theme.md`, `project.md`,
> the README — in the project's declared `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Independent
> of the conversation language and of the product's own i18n; machine-read tokens
> (frontmatter keys/values, slugs, filenames) stay verbatim.

1. **`review` is read-only.** `init` / `stack` / `theme` / `language` present a
   plan before writing.
2. **Bootstrap is upstream of everything.** A change here can ripple to specs,
   screen specs, the prototype and production code — surface the propagation; don't edit
   those layers silently.
3. **Load-bearing choices are ADRs.** Replacing a framework or the primary color is
   an architectural decision recorded in `01_adr` (update to add, supersede to
   replace), kept in sync with `stack.md` / `theme.md`.
4. **Roles over values.** Downstream skills depend on token *roles* (primary,
   accent, status keys) — keep them stable even when values change.
5. **Consult the task tracker** (`/inspire_workspace task list`) for tracked
   bootstrap work.

## Related skills

- `/inspire_screens` — instantiates the theme's tokens into patterns/components.
- `/inspire_prototype` — builds the horizontal prototype on this stack + theme.
- `/inspire_workspace adr create` — record load-bearing stack/theme decisions.
