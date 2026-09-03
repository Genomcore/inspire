---
name: inspire-bootstrap
description: "Configure the project's foundation — the output language, tech stack and its shape (frontend / backend / monorepo, web / mobile, database provisioning), and the design system: both the reusable theme.md template in inspire_kb/00_bootstrap and the project's live 05_screens/design-system.md — plus the project's root README. Use when bootstrapping a new project, setting the language, choosing the project shape, changing a stack choice, or defining/updating the theme or the live design system (including abstracting it from a mockup's CSS)."
---

# /inspire-bootstrap — Foundation (language + stack + theme)

## Scope

This skill owns the **bootstrap layer** —
[`inspire_kb/00_bootstrap/`](../../../inspire_kb/00_bootstrap):

- `project.md` — **project conventions**, chiefly `output_language`: the single
  language every skill writes its artifacts in (default English).
- `stack.md` — the **tech stack** the product is built with, its **shape**
  (frontend / backend / monorepo · web / mobile · database provisioning), and the
  **product roots** (`source_root` / `prototype_root` — where the code and the
  prototype live; see
  [`_references/product-roots.md`](../_references/product-roots.md)).
- `theme.md` — the **design-system default** (fonts, color palette + status map,
  density, layout tokens) — the reusable template.
- `semantic-types.md` — the project's **own semantic types**, each with a mandatory
  universal base type. It ships empty and no interview here fills it: a type is
  declared the moment domain work meets a field the universal vocabulary
  ([`type-mapping.md`](../inspire-domain/references/type-mapping.md)) has no type for.
  What this skill owes it is the **language profile** that renders those types — see
  the `stack` flow.
- `05_screens/design-system.md` (the one artifact this skill owns **outside**
  `00_bootstrap`) — the project's **live design system**, seeded from `theme.md` at
  install and edited here via the `design-system` subcommand. `theme.md` is the
  default; this is the working copy.

These are the foundation every other layer reads: specs ([`04_domain`](../../../inspire_kb/04_domain)),
screen specs ([`05_screens`](../../../inspire_kb/05_screens)), the prototype ([`/prototype`](../../../prototype))
and production code ([`/source`](../../../source)) all build on what is declared here —
those last two named at their defaults, the operative roots being the
`prototype_root` / `source_root` this skill records above.
The template seeds all three with a sensible default (English + the OpenBIMS
reference stack + theme); a new project reconfigures them here.

At first-time setup this skill also establishes **project identity** — the root
`README.md`. A project materialized from the plugin never carries the template's
methodology README, so `init` creates the project's own (see the `readme` subcommand).
It also **refines the seeded `CLAUDE.md`** — `/inspire:init` writes a provisional
stub with the project name, purpose and stack marked as placeholders; this skill's
`init` subcommand replaces them with the real thing (long form in
[`references/bootstrap-identity.md`](references/bootstrap-identity.md)).

## Invocation

- `/inspire-bootstrap init` — first-time setup: establish `project.md` (language),
  `stack.md` + `theme.md`, and create the project's root `README.md`
- `/inspire-bootstrap language` — set the output language artifacts are written in
- `/inspire-bootstrap stack` — define / update the tech stack
- `/inspire-bootstrap theme` — define / update the design-system default (`theme.md`)
- `/inspire-bootstrap design-system` — view / edit the project's live design system (`05_screens/design-system.md`)
- `/inspire-bootstrap readme` — create / update the project's root `README.md`
- `/inspire-bootstrap review` — check the artifacts exist and stay coherent

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
4. **Refine the project's `CLAUDE.md`** — replace `/inspire:init`'s marked
   placeholders (name, purpose, stack) **in place**, leaving the orientation
   content alone; read the full procedure in
   [`references/bootstrap-identity.md`](references/bootstrap-identity.md).
5. **Create the project's root `README.md`** by running the `readme` flow. A project
   materialized from the plugin never carries the template's own methodology README, so
   a fresh project has none — this is where it gets one.
6. **Wire the local git remote (optional).** Run `git remote -v`; show the current
   `origin`. Ask — optional, skippable — for the remote the project should push to.
   If they give one, wire it on an **explicit yes** (`git remote add origin <url>`,
   or `git remote set-url origin <url>` if one exists); never change git config
   silently. This is purely local git setup — the remote is **not** written into
   the README or any artifact.

Confirm the outcome and point the operator at the next layer (usually
`/inspire-module create` for the first module).

## Flows in `references/`

Four of this skill's flows keep their full procedure in a reference file of their
own. Each flow's full procedure lives under `references/`. **Before executing any
flow, read every reference file its index row names** — the table below is an
index, not the flow.

| Flow | What it does |
|---|---|
| [`stack`](references/bootstrap-stack-interview.md) | Define / update `stack.md` — shape interview, layer walk, ADR trigger, `profiles:` line |
| [`theme`](references/bootstrap-theme-interview.md) | Define / update `theme.md`, the design-system default (incl. abstracting one from a mockup's CSS) |
| [`readme`](references/bootstrap-identity.md) | Create / update the project's root `README.md` — plus `init` step 4's long form |
| [`review`](references/bootstrap-review.md) | Read-only coherence checklist over the bootstrap artifacts |

## Subcommand: design-system

Own `05_screens/design-system.md` — the project's **live design system** (tokens,
typography, color + status map, density, global layout), seeded at install from the
default `theme.md`. Distinct from the `theme` flow
([`references/bootstrap-theme-interview.md`](references/bootstrap-theme-interview.md)):
`theme.md` is the reusable default, `design-system.md` is the project's working
copy — they may diverge.

1. Read the current `design-system.md`. If it's missing, seed it from `theme.md`
   (this is what install does) and say so.
2. Establish/confirm the change (a token value, the type scale, density, a new
   status key, a layout rule). Present a diff; apply on approval.
3. **Propagate.** A token change ripples to every screen and to the prototype —
   surface it (offer `/inspire-prototype`); screens must not hard-code values that
   belong here.
4. **One design system for the whole suite.** There is exactly one
   `design-system.md`, sitting above the surface trees, whatever the roster says.
   Four things a surface might want from it, and what each gets:
   - **Extension** — vocabulary only one surface uses (a data grid only the admin
     console has): a `patterns/` or `components/` entry scoped with `surfaces:`.
     Welcome and cheap; nothing shared is redefined, so nothing has to be
     reconciled later.
   - **Variance** — platform or context fit (mobile density, touch targets):
     **named variant axes this file defines and a surface selects**, written as
     clearly-marked per-surface sections *inside* it (e.g. `## Density — mobile`),
     the way mature systems handle density and dark mode. Rare, visible and
     countable — `/inspire-workspace` reports how many there are as a drift signal.
   - **Override** — a surface redefining, from its own side, what a shared token or
     component means: **no channel exists, deliberately.** Never create a
     per-surface design-system file under any name. Per-consumer overrides invert
     in practice: every change becomes a design-system change *plus* an override in
     each consumer, and the agents that emanate code would have to answer "which
     spec wins?" once per surface.
   - **Divergence** — a surface that is genuinely its own brand: the honest form is
     a declared fork that consumes no suite design system at all, out of scope
     today; name it as such rather than approximating it with variant sections.
5. Keep token **roles** stable (primary, accent, status keys) even when values
   change — downstream skills (screens, prototype) depend on the roles, not the
   hexes. Roles are never overridden per surface either: a variant axis may give a
   role a different value for one surface, never a different meaning.

## Subcommand: language

Set the project's **output language** — the single language every INSPIRE skill
writes its KB artifacts in (`project.md` frontmatter `output_language`; default
`en`). See [`_references/output-language.md`](../_references/output-language.md).

1. Read the current `output_language` from
   [`00_bootstrap/project.md`](../../../inspire_kb/00_bootstrap/project.md).
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

## Rules

> **Output language.** Write every artifact — `stack.md`, `theme.md`, `project.md`,
> the README — in the project's declared `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Independent
> of the conversation language and of the product's own i18n; machine-read tokens
> (frontmatter keys/values, slugs, filenames) stay verbatim.

> **Writing contract.** `project.md`, `stack.md`, `theme.md`, `glossary.md` and the
> project README follow
> [`_references/writing-style.md`](../_references/writing-style.md). Their prose
> sections are normative (R1–R6); token, shape and roster tables are structured
> sections (R3, R4, R6). `glossary.md` is R4's own term list and sits in this layer, so
> this skill owns writes to it: a row lands when an interview settles a naming
> question, carrying the operator's own word. Every other skill reads it.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **`review` is read-only.** `init` / `stack` / `theme` / `language` present a
   plan before writing.
2. **Bootstrap is upstream of everything.** A change here can ripple to specs,
   screen specs, the prototype and production code — surface the propagation; don't edit
   those layers silently.
3. **Load-bearing choices are ADRs.** Replacing a framework or the primary color is
   an architectural decision recorded in `01_adr` (update to add, supersede to
   replace), kept in sync with `stack.md` / `theme.md`.
4. **Consult the task tracker** (`/inspire-task list`) for tracked
   bootstrap work.
5. **`project.md`/`stack.md` are endorsed-only.** They are interview-generated,
   not skill-produced, so writes to them carry no `produced` stamp; on an
   explicit operator yes they may be endorsed via
   `.inspire/bin/trust.sh endorse <file>`
   ([trust-stamps](../_references/trust-stamps.md#scope)).
6. **`design-system.md` is stamped.** After the `design-system` subcommand
   writes it, run `.inspire/bin/trust.sh stamp <file> --skill bootstrap`
   ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting one
   that carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).

7. **Gates ship with the stack.** `stack` installs the in-repo quality gates from the
   resolved profiles and records the project's answers under `stack.md`'s
   `## Quality gates`; the server-side half becomes a tracker ticket with a human
   owner, never reported as done. See
   [`_references/quality-gates.md`](../_references/quality-gates.md).

## Related skills

- `/inspire-screens` — instantiates the theme's tokens into patterns/components.
- `/inspire-prototype` — builds the horizontal prototype on this stack + theme.
- `/inspire-adr create` — record load-bearing stack/theme decisions.
