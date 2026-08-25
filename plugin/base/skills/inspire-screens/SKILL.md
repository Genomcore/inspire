---
name: inspire-screens
description: "Create and validate screens (a screen is the UI spec for one view). A screen declares its own bindings — data sources, dispatches, navigation, states — and names a shared layout and shared components as dependencies. Use when designing or reviewing an application's screens."
---

# /inspire_screens — Screen Specifications

## When to use

- **Creating a new screen** for a module or feature
- **Validating existing screens** against their bindings, patterns and components
- **Detecting drift** between a screen spec and the layout it names — **including
  reverse drift** where the prototype is ahead of the spec
- **Promoting a screen** through its lifecycle, or **rendering the route map**
- **Identifying extraction opportunities** — UI blocks that should become shared
  components or patterns

## Architecture

Three tiers under `inspire_kb/05_screens/`, with a **sibling middle**:

| Tier | Path | Source of truth for | Catalog |
|------|------|---------------------|---------|
| 1 | `design-system.md` | tokens, colors, typography, global layout | one file |
| 2a | `patterns/` | reusable layouts — their **regions** and geometry | entry files (`patterns/[!_]*.md`) |
| 2b | `components/` | shared components — their **props** | entry files (`components/[!_]*.md`) |
| 3 | `{module}/` | module-specific screens — the **wiring** | `_index.md` per module directory |

Patterns and components are **siblings**: neither depends on the other by
construction. A layout's regions accept injected content, so it never imports leaf
components, and a leaf component never references a layout. Where a pattern does
reference a shared component, it declares it on a `**Components:**` line like any
other dependency — an actual declared edge, never an assumed tier.

Three ownerships, and they never bleed: a **component** owns its props, a
**pattern** owns its regions, and a **screen** owns the wiring — data into
components, components into regions. A pattern region is a hole, never a mirror of
some component's props.

`design-system.md` is **seeded at install** from the default template
`00_bootstrap/theme.md`, and owned by
[`/inspire_bootstrap design-system`](../inspire-bootstrap/SKILL.md) — screens
**read** its tokens (they are the source of truth for colors, typography, layout)
but never edit them.

Tier 3 carries a second dimension: **surface**. Once the suite declares two or
more UI surfaces, module screens split positionally into
`05_screens/{surface}/{module}/`, with a reserved `shared/{module}/` for screens
more than one UI surface uses. Tiers 1, 2a and 2b do not split —
`design-system.md`, `patterns/` and `components/` stay suite-wide, beside the
surface trees at top level, never inside one. Which shape applies, what `shared/` means and how a
surface id resolves are defined in
[`.claude/skills/_references/surface-scope.md`](../_references/surface-scope.md);
read it before writing anywhere under `05_screens/`. This skill works with the
shape the roster implies — the one-time reshaping from flat to split is
[`/inspire_surface`](../inspire-surface/SKILL.md)'s sweep, not this skill's.

**Screens are lightweight** — they declare their own bindings and describe only
what deviates from the layout they name. They do NOT redefine colors, typography,
layout, or re-describe components.

## Screen file structure

The on-disk shape — identity, header lines, `## Purpose`, `## Bindings`, claims,
the route derivation and the old-shape catalogue — is
[`references/format-screen.md`](references/format-screen.md). Read it before
writing a screen. Template:
[`templates/screen.md.template`](templates/screen.md.template) — the template is
the single source of which parts are required (the frontmatter identity block,
H1, `**Features:**`, `## Purpose`, `## Bindings`) versus optional/presence-free
(`**Pattern:**`, `**Components:**`, `## Module-specific deviations`,
`## Current prototype`, `## Notes`).

Four facts about that shape carry the rest of this skill:

- **The `id` is the referent, the path is only where the file sits.** Minted once
  as `{module}.{screen}`, never re-derived from location. Same id at a new path is
  a move; a changed id is a new screen.
- **The screen says what it is for.** `## Purpose` carries one paragraph — who
  comes here, for which task, what they see first. It is what the emanating agent
  would otherwise have to guess from the feature links. It restates no binding
  and names no route.
- **The screen owns its semantics.** `## Bindings` declares the data sources,
  dispatches, navigation and states, keyed screen-locally, and generates claims
  whether or not a pattern is named. `**Pattern:**` is a peer dependency
  constraining presentation, never the screen's definition. One transition, one
  declaration, one claim: a transition a dispatch causes is that dispatch's
  outcome and never also a `### Navigation` row, which declares only the
  transitions no dispatch on this screen causes.
- **Routes derive** from `module:` + `screen:`, so no screen file authors one.
  `routes` renders the map.

The **Current prototype** section names the prototype route(s) realizing the screen
and tracks **drift** — misalignments between the prototype and this spec, grouped by
type (`ADR alignment` · `data wiring` · `component adoption` · `gap` · `cosmetic`).
Drift is **informational**: it never blocks a PR unless it contradicts a current ADR
(one present and not superseded or rejected), and it drives the propagation check
([`references/screen-propagation.md`](references/screen-propagation.md)). Omit the
section only until a prototype target exists. With two or more UI
surfaces each target carries its
surface's shell prefix — the route lives inside that surface's shell rather than at
the prototype root — and a `shared/` screen names one target per shell that serves
it.

## Granularity rule: one file per screen

**Each screen is its own file.** A "screen" is any navigable entity with its own
route, or its own distinct set of bindings.

Rationale: parallelization (agents work on different screens without conflicts),
diff clarity, wikilink precision, and a **1:1 mapping to the prototype** (one
screen file ≈ one prototype screen).

**Not a separate file:** steps inside a wizard, tabs inside a detail page,
sub-sections of a single settings form.

**File naming:** kebab-case, matching the screen's conceptual name
(`agents-list.md`, `agent-detail.md`, not `agents.md`). The name is **positional**:
it never carries identity, and renaming a file is a move that leaves the `id`, the
route and every claim untouched.

**Where the file goes:** `05_screens/{module}/{screen}.md` while the suite has at
most one UI surface; `05_screens/{surface}/{module}/{screen}.md` — or
`shared/{module}/` for a screen more than one UI surface uses — once the roster
declares two or more. The shape is deterministic from the roster's `kind: ui`
count, never from what the tree happens to hold: derive it from
[`_references/surface-scope.md`](../_references/surface-scope.md) rather than
copying a neighbouring path. Catalog wikilinks are relative, so their `../` depth
follows the screen's own: what they must land on is the one suite-wide
`05_screens/patterns/` or `05_screens/components/`, never a copy inside a surface
tree.

## Which surface a screen belongs to

The directory **is** the scope declaration, which is why a screen's frontmatter
carries identity and lifecycle but no `surfaces:` field. Resolve the surface with
the algorithm in
[`_references/surface-scope.md`](../_references/surface-scope.md) and state the
tree being written to in the turn's output. Surface ids come from the roster at
`00_bootstrap/surfaces.md`; an id that is not there stops the write rather than
being invented.

- **`shared/{module}/`** holds screens more than one UI surface uses. These are the
  only screens that may carry `surfaces:` — an optional list narrowing which UI
  surfaces they serve; absent means all of them.
- **Directories are created lazily.** A surface or module directory comes into
  existence when the first screen lands in it, never ahead of one.
- **Reshaping the tree is not this skill's work.** The flat→split move belongs to
  [`/inspire_surface add`](../inspire-surface/SKILL.md), which performs it as a
  sweep the operator classifies entry by entry. The one reshaping this skill
  performs is consolidating back to the flat shape after a `retire` — and only when
  `/inspire_surface` hands it over.

## Flows in `references/`

Each flow's full procedure lives in a reference file. **Before executing any
flow, read every reference file its index row names** — the table below is an
index, not the flow.

| Flow | Read | Invocation |
|---|---|---|
| The on-disk shape (every flow) | [`references/format-screen.md`](references/format-screen.md) | — |
| Create a screen | [`references/screen-create.md`](references/screen-create.md) **and** the format reference | `create {module}/{screen}` |
| Validate / audit | [`references/screen-validate.md`](references/screen-validate.md) **and** [`references/screen-checks.md`](references/screen-checks.md), applying the § Triangulation matrix below; `audit` also reads [`references/screen-catalog.md`](references/screen-catalog.md) for extraction opportunities | `validate` · `audit` |
| Promote through the lifecycle | [`references/screen-lifecycle.md`](references/screen-lifecycle.md) | `promote {id} {state}` |
| Render the derived route map | [`references/screen-routes.md`](references/screen-routes.md) | `routes` |
| Extract a pattern/component | [`references/screen-catalog.md`](references/screen-catalog.md) | `extract {pattern\|component} {name}` |
| Propagation after spec edits | [`references/screen-propagation.md`](references/screen-propagation.md) — it owns which edits trigger the ask | a duty, not an invocation |

## When validating an existing screen

The validate / audit procedure lives in
[`references/screen-validate.md`](references/screen-validate.md) and
[`references/screen-checks.md`](references/screen-checks.md), applying the
triangulation matrix below.

### Triangulation matrix — Features ↔ screen spec ↔ Prototype

Three sources of truth, three pairwise checks. Resolution rules differ per pair:

| Pair | Mismatch direction | Authority | Action |
|------|--------------------|-----------|--------|
| **Features ↔ Prototype** | Feature described, not in the prototype | Features | "Code behind spec". Suggest `/inspire_prototype`. |
| **Features ↔ Prototype** | Feature in the prototype, no feature file | **Open** | **WARN. Ask the user.** Backfill via `/inspire_feature create`, or remove it from the prototype. Don't silently accept undocumented features. |
| **screen spec ↔ Prototype** | screen spec describes UI not rendered | Prototype | Spec stale. Update via `/inspire_screens validate`. Do NOT change the prototype — risks losing iterations. |
| **screen spec ↔ Prototype** | Prototype renders UI not in the screen spec | Prototype | Spec stale (reverse drift). Update the spec. |
| **Patterns / components / design-system / UX ADRs** | Prototype or screen spec contradicts a canonical convention | **Skill** | Enforce. Patterns + components + `design-system.md` + current UX ADRs are authoritative for visual/structural conventions. |

**Why the prototype wins on functional drift:** prototypes evolve through user
iterations. The screen spec captures intent at write-time; the prototype captures it at
last-touch. Removing user-validated functionality by "fixing" the prototype to
match a stale spec is riskier than updating the spec.

**Why the skill wins on UI conventions:** patterns, components, design tokens and
current UX ADRs are project-wide invariants. A prototype that violates them is a
regression to fix in the prototype, not in the spec.

When uncertain which layer a finding belongs to, ask the user.

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, wikilink slugs, filenames)
> stay verbatim.

> **Writing contract.** Screens, pattern entries and component entries follow
> [`_references/writing-style.md`](../_references/writing-style.md).
> `## Module-specific deviations` and `## Notes` are normative prose (R1–R6);
> binding, region, coverage and API tables are structured sections (R3, R4, R6).
> The no-ASCII rule below is this layer's own local contract — the writing contract
> points at it rather than restating it.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire_lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **Features are the source of truth for what exists.** Every screen traces to one
   or more features in `03_features`.
2. **Each tier owns its truth** — the *Source of truth for* column of the
   § Architecture table above: `design-system.md` for tokens (colors, typography,
   density, layout), `patterns/` for layout regions and geometry, `components/`
   for component props. Screens declare and reference; they never redefine a token,
   nor redescribe a layout or a component's props. Project-specific screen
   conventions live in those artifacts, not in this skill.
3. **Screens are lightweight** (aim <300 lines). Extract sub-patterns/components if
   a screen grows.
4. **No ASCII layout diagrams in screen, pattern or component files, unless the
   screen is bespoke and its layout cannot be expressed textually.** This is the
   single statement of the rule for this layer; the create flow and the validate
   checks reference it, and
   [`_references/writing-style.md`](../_references/writing-style.md) points here
   rather than restating it.
5. **Routes derive from the id's inputs — never author one.** The route of a
   screen is `/{module}/{screen}` from its declared `module:` and `screen:` fields,
   prefixed by the surface's roster `Shell` value once the suite declares two or
   more UI surfaces (`/admin` → `/admin/billing/list`). The exact rendering belongs
   to the framework profile, like every binding convention. Nothing writes a route
   into a screen file, so a route and an id can never disagree — and a screen that
   moves between surfaces keeps both. Full rule:
   [`references/format-screen.md`](references/format-screen.md) § Routes derive.
6. **Identity is write-once.** `id:` is minted at creation and never re-derived
   from location; `module:` must match the path's module directory. A changed id is
   a new screen, not a moved one.
7. **The screen declares, the pattern constrains.** Every data source, dispatch,
   navigation target and state is the screen's own declaration, present whether or
   not a pattern is named. Where one is named, its regions are joined against those
   declarations — a required region that accepts data, with no data binding to
   serve it, is a finding.
8. **Validate before merge** — run `/inspire_module review` before any PR that
   modifies screen spec files.
9. **Respect current UX ADRs.** Screens must not contradict a UX decision in
   `inspire_kb/01_adr/` that is not superseded or rejected; flag any that do.
10. **Propagation check after spec edits.** Ask the operator before ending the turn
   whether to propagate visible UI changes to the prototype — which edits trigger
   the ask, and what each answer leads to, are
   [`references/screen-propagation.md`](references/screen-propagation.md)'s.
11. **Stamp every write.** After `create`, `validate`, or `extract` writes a
   screen or catalog file, run
   `.inspire/bin/trust.sh stamp <file> --skill screens`
   ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting one
   that carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).

## Skill invocations

- `/inspire_screens create {module}/{screen}` — scaffold a new screen: mint its id, declare its bindings, name a layout if one fits
- `/inspire_screens validate {module}/{screen}` — validate a screen, browsing the prototype when it can be run
- `/inspire_screens promote {id} {state}` — walk a screen through the 4-state lifecycle
- `/inspire_screens routes` — render the derived route map and the transition graph; writes nothing
- `/inspire_screens extract {pattern|component} {name}` — promote a recurring UI block to a shared artifact
- `/inspire_screens audit {module}` — scan a module's screens for forward + reverse drift, duplication, extraction opportunities
