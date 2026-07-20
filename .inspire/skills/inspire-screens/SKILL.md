---
name: inspire-screens
description: "Create and validate screens (a screen is the UI spec for one view) using a pattern-driven approach. Screens instantiate shared patterns and use shared components. Use when designing or reviewing an application's screens."
---

# /inspire_screens — Screen Specifications (Pattern-Driven)

## When to use

- **Creating a new screen** for a module or feature
- **Validating existing screens** against patterns and components
- **Detecting drift** between a screen spec and the pattern it claims to
  instantiate — **including reverse drift** where the prototype is ahead of the spec
- **Identifying extraction opportunities** — UI blocks that should become shared
  components or patterns
- **Migrating legacy screen spec monoliths** to the screen-per-file structure

## Architecture

Four levels under `.inspire_kb/05_screens/`:

| Level | Path | Source of truth for | Catalog |
|------|------|---------------------|---------|
| 1 | `design-system.md` | tokens, colors, typography, global layout | one file |
| 2 | `patterns/` | reusable screen structures | `patterns/_index.md` |
| 3 | `components/` | shared component specs | `components/_index.md` |
| 4 | `{module}/` | module-specific screens | `{module}/_index.md` per module |

`design-system.md` is **seeded at install** from the default template
`00_bootstrap/theme.md`, then owned here — it is the project's live design system,
edited with the `design-system` subcommand below.

**Screens are lightweight** — they instantiate a pattern and describe only
deviations. They do NOT redefine colors, typography, layout, or re-describe
components.

## Screen file structure

```markdown
# {Screen Title} — `/{path}`

**Features:** FEAT-01, FEAT-02
**Pattern:** [[../patterns/{pattern-name}]]

## Instantiation

- **Data:** {the data source — a spec entity or the prototype's mock table}
- **Primary action:** `[+ New X]` → `/{path}/new`
- {other pattern slots per the pattern's API}

## Module-specific deviations

- {describe only what deviates from the pattern defaults}

## Notes

- {domain-specific behavior, edge cases, user feedback that informed the design}
```

## Granularity rule: one file per screen

**Each screen is its own file.** A "screen" is any navigable entity with its own
URL/route, or its own distinct pattern instance.

Rationale: parallelization (agents work on different screens without conflicts),
diff clarity, wikilink precision, and a **1:1 mapping to the prototype** (one
screen file ≈ one prototype screen).

**Not a separate file:** steps inside a wizard, tabs inside a detail page,
sub-sections of a single settings form.

**File naming:** kebab-case, matching the screen's conceptual name
(`agents-list.md`, `agent-detail.md`, not `agents.md`).

## When creating a new screen

1. **Identify the feature.** Every screen references at least one feature ID from
   the module's `02_features`.
2. **Pick a pattern.** Read `patterns/_index.md` and choose the one that matches
   the screen's purpose. Only mark `**Pattern:** bespoke` if truly unique. The
   project's own screen conventions (default list pattern, header layout, tabs,
   toolbar rules) live in the patterns and `design-system.md` — follow them.
3. **Instantiate.** Describe the screen by filling the pattern's slots. Refer to
   the pattern's API in its file.
4. **Deviations only.** Do NOT redescribe the structure the pattern already
   defines.
5. **Reference components** — link, don't re-describe: `[[../components/{name}]]`.
6. **No ASCII layout diagrams** unless the screen is bespoke and can't be
   expressed textually.
7. **No inline mock data.** Reference the data source.
8. **Register in the module's `_index.md`** (nav, route map, feature coverage).

## When validating an existing screen

### Triangulation matrix — Features ↔ screen spec ↔ Prototype

Three sources of truth, three pairwise checks. Resolution rules differ per pair:

| Pair | Mismatch direction | Authority | Action |
|------|--------------------|-----------|--------|
| **Features ↔ Prototype** | Feature described, not in the prototype | Features | "Code behind spec". Suggest `/inspire_prototype`. |
| **Features ↔ Prototype** | Feature in the prototype, no feature file | **Open** | **WARN. Ask the user.** Backfill via `/inspire_feature create`, or remove it from the prototype. Don't silently accept undocumented features. |
| **screen spec ↔ Prototype** | screen spec describes UI not rendered | Prototype | Spec stale. Update via `/inspire_screens validate\|migrate`. Do NOT change the prototype — risks losing iterations. |
| **screen spec ↔ Prototype** | Prototype renders UI not in the screen spec | Prototype | Spec stale (reverse drift). Update the spec. |
| **Patterns / components / design-system / UX ADRs** | Prototype or screen spec contradicts a canonical convention | **Skill** | Enforce. Patterns + components + `design-system.md` + accepted UX ADRs are authoritative for visual/structural conventions. |

**Why the prototype wins on functional drift:** prototypes evolve through user
iterations. The screen spec captures intent at write-time; the prototype captures it at
last-touch. Removing user-validated functionality by "fixing" the prototype to
match a stale spec is riskier than updating the spec.

**Why the skill wins on UI conventions:** patterns, components, design tokens and
accepted UX ADRs are project-wide invariants. A prototype that violates them is a
regression to fix in the prototype, not in the spec.

When uncertain which layer a finding belongs to, ask the user.

### Checks

1. **Pattern exists.** The `**Pattern:**` link resolves.
2. **Feature IDs exist.** All referenced features exist in the module's
   `02_features`.
3. **No redundant structure.** The screen doesn't redescribe what the pattern
   already specifies.
4. **Component references resolve.** All `[[../components/X]]` wikilinks point to
   existing files.
5. **Data reference is valid.**
6. **No ASCII layout diagrams** unless bespoke.
7. **No inline mock data.**
8. **Historical language is absent** ("antes", "reemplaza a", "eliminado",
   strikethrough).
9. **Route follows convention** (`/{module}/...`).
10. **Live prototype check.** When the prototype can be run, navigate every route
    the screen describes and compare it against the spec — see below.

### Pattern / component drift

- **Pattern drift:** the screen claims pattern X but its deviations would
  fundamentally change it → update the pattern's "Variantes" or mark the screen
  `bespoke`.
- **Component drift:** the screen describes behavior that contradicts a
  component's canonical spec → update the component spec or fix the screen.

### Live prototype browse — reverse-drift detection

Features often land in the prototype before the screen spec catches up. `validate` and
`audit` should **run the prototype** when possible to surface this **reverse
drift** (prototype ahead of spec).

1. **Run the prototype** (use the `run` / `verify` skills to launch `/prototype`).
   If it can't be launched, skip this section and note it — don't block the audit.
2. **Enumerate routes** from the spec being audited (each screen's route; each tab
   variant; a representative id for detail pages).
3. **For each route:** navigate and read what renders (prefer the accessibility
   tree; screenshots only when layout matters).
4. **Compare** against the spec, applying the triangulation matrix:
   - Tabs/sections/controls in the prototype but absent from the spec → spec stale.
   - Spec describes UI not rendered → prototype regression, or spec ahead of code.
   - A prototype feature not traceable to any feature file → **WARN**, ask the user.
   - A prototype violating a canonical pattern/component/UX ADR → code regression;
     suggest `/inspire_prototype`.
5. **Report reverse drift separately** from forward drift, with severity
   (Important = a whole feature/tab missing from the spec; Minor = a column, label,
   or control).
6. **Resolution:** reverse-drift findings suggest `/inspire_screens {validate|migrate}`
   to update the spec (the prototype is already correct) — the spec catches up to
   the code, not the other way around.

Preview snapshots are point-in-time — re-run navigation after every prototype
change.

### Cross-screen coherence

- Instances of the same pattern in a module share their UX (control positions,
  search placement, tab ordering).
- Similar resources across modules share status vocabulary.

## After modifying a screen spec — propagation check

Whenever a `create` / `update` / `migrate` / `extract` changes a screen in a way
that affects the UI (new pattern, new slot, renamed data source, added/removed
section or tab), the skill MUST ask the user whether to propagate the change to the
prototype before ending the turn.

1. **Detect the prototype target** from the screen's `## Prototipo actual` section.
2. **Classify the change** — structural (propagation strongly recommended),
   cosmetic (mention, don't insist), or no-prototype-yet (skip, note it's ready).
3. **Ask, don't assume.** Close the turn with a clear question, e.g.:

   > La screen spec de `{module}/{screen}` ha cambiado: {resumen}. El prototipo queda
   > desalineado en: {drift}. ¿Propago ahora con `/inspire_prototype`, o en otro
   > turno?

4. **If confirmed:** invoke `/inspire_prototype` with a concrete prompt (the
   updated screen + the drift items to resolve).
5. **If declined:** create a tracker ticket via `/inspire_workspace task create` so
   it isn't lost.

## When migrating a legacy monolith

Split an old monolithic screen spec into the new structure:

1. Read the monolith; identify screens.
2. Create `{module}/_index.md` — consolidate nav, route map, feature coverage.
3. Create one screen file per logical grouping (granularity rule).
4. Remove design-token duplication that matches `design-system.md`; keep only
   module-specific overrides.
5. Replace ASCII layouts with pattern references; keep ASCII only if bespoke.
6. Replace inline mock data with data-source references.
7. Delete the monolith once every screen is migrated and `_index.md` is complete.

## When adding a new pattern or component

New shared artifacts require evidence:

- **Pattern:** appears in ≥2 actual or planned screens.
- **Component:** appears in ≥2 pages (≥3 if trivial).

Process: draft the file in `patterns/` or `components/`; document purpose, API/slots,
structure (textual), variants, instances; if the underlying prototype component
doesn't exist yet, mark it `To-extract` and list adopters; update the relevant
`_index.md`. Prefer adding a variant to an existing pattern over creating a new one.

## Rules

1. **Features are the source of truth for what exists.** Every screen traces to one
   or more features in `02_features`.
2. **`design-system.md` is the source of truth for tokens.** No module redefines
   colors, typography, density.
3. **`patterns/` is the source of truth for screen structure.** Screens
   instantiate; they don't redescribe.
4. **`components/` is the source of truth for shared UI.** Screens reference; they
   don't redefine.
5. **Screens are lightweight** (aim <300 lines). Extract sub-patterns/components if
   a screen grows.
6. **No ASCII art for common layouts** — patterns describe layouts textually.
7. **No inline mock data** — reference the data source.
8. **No historical language** — specs describe the present.
9. **Route convention** — `/{module}/...`, nested routes for detail/edit/new.
10. **Validate before merge** — run `/inspire_module review` before any PR that
    modifies screen spec files.
11. **Respect accepted UX ADRs.** Screens must not contradict an accepted UX
    decision in `.inspire_kb/01_adr/`; flag any that do. (Project-specific screen
    conventions live in `patterns/` + `design-system.md`, not in this skill.)
12. **Propagation check after spec edits.** Ask the user before ending the turn
    whether to propagate visible UI changes to the prototype.

## Subcommand: design-system

Own `05_screens/design-system.md` — the project's **live design system** (tokens,
typography, color + status map, density, global layout). It was seeded at install
from the default template `00_bootstrap/theme.md`; from here on this subcommand is
how it changes.

1. Read the current `design-system.md`. If it's missing, seed it from
   `00_bootstrap/theme.md` (this is what install does) and say so.
2. Establish/confirm the change (a token value, the type scale, density, a new
   status key, a layout rule). Present a diff; apply on approval.
3. **Propagate.** A token change ripples to every screen and to the prototype —
   surface it (offer `/inspire_prototype`); screens must not hard-code values that
   belong here.
4. Keep token **roles** stable (primary, accent, status keys) even when values
   change — downstream skills depend on the roles, not the hexes.

The default template lives in `00_bootstrap/theme.md` and is owned by
`/inspire_bootstrap theme`; the live one lives here. They are allowed to diverge.

## Skill invocations

- `/inspire_screens create {module}/{screen}` — scaffold a new screen with pattern selection
- `/inspire_screens validate {module}/{screen}` — validate a screen, browsing the prototype when it can be run
- `/inspire_screens design-system` — view / edit the live design system (`05_screens/design-system.md`)
- `/inspire_screens migrate {module}` — migrate a legacy monolith to the new structure
- `/inspire_screens extract {pattern|component} {name}` — promote a recurring UI block to a shared artifact
- `/inspire_screens audit {module}` — scan a module's screens for forward + reverse drift, duplication, extraction opportunities
