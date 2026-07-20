---
name: inspire-ui
description: "Create and validate UI specifications using a pattern-driven approach. Screens instantiate shared patterns from spec/specs/ui/openbims-console/patterns/ and use components from components/. Use when designing or reviewing screens for OpenBIMS Console or Marketplace Console."
---

# /inspire-ui — UI Specifications (Pattern-Driven)

## When to use

- **Creating a new screen** for a module or feature
- **Validating existing screens** against patterns and components
- **Detecting drift** between a screen spec and the pattern it claims to instantiate, **including reverse drift** where the prototype is ahead of the spec
- **Identifying extraction opportunities** — blocks of UI that should become shared components or patterns
- **Migrating legacy UISpecs** (`UISpec_{Module}.md` monoliths) to the new screen-per-file structure

## Architecture

Four levels under `spec/specs/ui/openbims-console/`:

| Level | Path | Source of truth for | Catalog |
|------|------|---------------------|---------|
| 1 | `design-system.md` | tokens, colors, typography, global layout | one file |
| 2 | `patterns/` | reusable screen structures | see `patterns/_index.md` |
| 3 | `components/` | shared component specs | see `components/_index.md` |
| 4 | `{module}/` | module-specific screens | `{module}/_index.md` per module |

**Screens are lightweight** — instantiate a pattern, describe only deviations. They do NOT redefine colors, typography, layout, or re-describe components.

## Screen file structure

A canonical screen file looks like this:

```markdown
# {Screen Title} — `/{path}`

**Features:** FEAT-01, FEAT-02
**Pattern:** [[../patterns/{pattern-name}]]

## Instantiation

- **Data:** table `X` (hook `useX()`)
- **Primary action:** `[+ New X]` → `/{path}/new` (uses [[../patterns/wizard]])
- **Row click:** → `/{path}/:id` (uses [[../patterns/resource-detail]])
- {other pattern slots per the pattern's API}

## Module-specific deviations

- {describe only what deviates from the pattern defaults}

## Notes

- {any domain-specific behavior, edge cases, user feedback that informed the design}
```

## Granularity rule: one file per screen

**Each screen is its own file.** A "screen" is any navigable entity with:
- Its own URL / route (primary case), OR
- Its own distinct pattern instance (e.g., a nested editor that composes a unique split-editor variant)

Rationale:
- **Parallelization:** multiple agents can work on different screens without merge conflicts
- **Diff clarity:** PRs touch only the affected screen
- **Wikilink precision:** other docs can link `[[agent-detail]]` unambiguously
- **1:1 mapping to prototype:** one screen file ≈ one React page component

**Not a separate file:**
- Steps inside a wizard (the wizard file describes them via the [[wizard]] pattern)
- Tabs inside a detail page (the detail file describes them via the [[resource-detail]] pattern)
- Sub-sections of a single settings form

**File naming:** kebab-case, matches the screen's conceptual name (`agents-list.md`, `agent-detail.md`, `agent-editor.md`, not `agents.md`).

## When creating a new screen

1. **Identify the feature.** Every screen must reference at least one feature ID from the module's PDD.
2. **Pick a pattern.** Read `patterns/_index.md` and choose the pattern that matches the screen's purpose. If none fit, think again — chances are one does. Only mark `**Pattern:** bespoke` if truly unique. Platform conventions:
   - **Module list screens default to [[../patterns/toolbar-list]].** Use [[../patterns/faceted-list]] only for marketplace-style browsing, or when the user explicitly asks for a sidebar-faceted list elsewhere.
   - **Detail screens are routes, not drawers.** Every resource has a dedicated `/{module}/{resource}/:id` page (see [[../patterns/resource-detail]] or a plain page). Clicking a row in a list navigates to that route. Drawers are not a supported pattern; don't introduce them unless the user explicitly requests it.
   - **Canonical main-page header:** icon + title + subtitle on the left. No counts, pills, stats or badges next to the title. On the right, in order: docs link (`/docs/module/<id>`, opens new tab), search (if filterable), action buttons. **No StatCards** unless the user explicitly asks.
   - **Tabs (if applicable) below the header.** Each tab has a count. `Settings` tab aligns right. `Marketplace` tab is violet-toned. Marketplace is always a tab, never a button.
   - **Search lives in the header, never in the toolbar** below the tabs. The toolbar carries filter dropdowns, sort, and per-view actions only.
3. **Instantiate.** Describe the screen by filling the pattern's slots/configuration. Refer to the pattern's API in its `.md` file.
4. **Deviations only.** Do NOT redescribe the structure the pattern already defines. Only list module-specific deviations.
5. **Reference components.** Don't re-describe status dots, page headers, tab strips — link to their spec: `[[../components/status-dot]]`.
6. **No ASCII layout diagrams** unless the screen is bespoke and the layout cannot be expressed textually.
7. **No inline mock data.** Reference the table/hook: `**Data:** table \`agents\` (hook \`useAgents()\`)`. Data lives in `mock-data/tables/`.
8. **Register in the module's `_index.md`** (nav, route map, feature coverage).

## When validating an existing screen

### Triangulation matrix — PDD ↔ UISpec ↔ Code

Three sources of truth, three pairwise checks. Resolution rules differ per pair:

| Pair | Mismatch direction | Authority | Action |
|------|--------------------|-----------|--------|
| **PDD ↔ Code** | Feature in PDD, not in code | PDD | Flag as "code behind spec". Suggest `/inspire-prototype`. |
| **PDD ↔ Code** | Feature in code, not in PDD | **Open** | **WARN. Ask user.** Either backfill PDD (`/inspire-feature create`) or remove from code. Don't silently accept undocumented features. |
| **UISpec ↔ Code** | UISpec describes UI not rendered | Code | Spec stale. Update spec via `/inspire-ui validate|migrate`. Do NOT change code — risks losing iterations. |
| **UISpec ↔ Code** | Code renders UI not in UISpec | Code | Spec stale (reverse drift). Update spec. Same rule: code wins. |
| **Patterns / components / design-system / UI rules** | Code or UISpec contradicts a canonical pattern/component/rule | **Skill** | Enforce. Patterns + components + design-system.md + ADR-UX-* are authoritative for visual/structural conventions. Update spec OR file a prototype task to align. |

**Why code wins on functional drift:** prototypes evolve through user iterations and feedback. UISpec captures intent at write-time; code captures intent at last-touch. The risk of removing user-validated functionality by "fixing" code to match spec is higher than the cost of updating spec.

**Why skill wins on UI conventions:** patterns, components, design-system tokens, and UX ADRs (no drawers, light mode, no module dashboards, settings inside primitives) are platform-wide invariants. Code that violates them is a regression to fix in code, not in spec.

**The two are different layers:**
- **Functional behavior** (what it does, what data, what tabs/sections exist, what navigation flows) → code wins, spec catches up.
- **UI conventions** (which pattern, which component, which token, which ADR-mandated structure) → skill wins, code + spec align to it.

When uncertain which layer a finding belongs to, ask the user.

### Checks

1. **Pattern exists.** The `**Pattern:**` link resolves to an existing pattern file.
2. **Feature IDs exist.** All referenced features exist in the module's PDD submodule files.
3. **No redundant structure.** The screen doesn't redescribe what the pattern already specifies (colors, layout, component internals).
4. **Component references resolve.** All `[[../components/X]]` wikilinks point to existing files.
5. **Data reference is valid.** Any referenced mock-data table exists in `mock-data/tables/`.
6. **No ASCII layout diagrams.** Unless the screen is bespoke.
7. **No inline mock data blocks.** Unless the screen is truly a one-off.
8. **Historical language is absent.** No "antes", "reemplaza a", "eliminado", "Absorbida", strikethrough.
9. **Route follows convention.** `/{module}/...` for console, `/admin/*` or `/publisher/*` for marketplace.
10. **Live prototype check.** If `openbims-console` preview is available, navigate every route the screen claims to describe and compare what renders against what the spec describes. See "Live prototype browse" below.

### Pattern / component drift

- **Pattern drift:** screen claims pattern X but its deviations would fundamentally change it. Update the pattern's "Variantes" or mark screen `bespoke`.
- **Component drift:** screen describes behavior that contradicts the component's canonical spec. Update the component spec or fix the screen.

(Extraction opportunities — UI blocks repeated across ≥2 screens — covered under "When adding a new pattern or component".)

### Live prototype browse — reverse-drift detection

PDD often advances faster than UISpec: features land in code (PDD updated, prototype implemented) but the UISpec still describes the previous shape. `validate` and `audit` MUST navigate the running prototype when possible to surface this **reverse drift** (code ahead of spec).

#### Protocol

1. **Detect preview availability.** Try `preview_start` with the `openbims-console` launch config. If unavailable (no launch config, port busy, build broken), skip this section and note it in the report — don't block the audit.
2. **Enumerate routes to visit.** From the spec being audited:
   - Every route declared in a screen header (`/datastore/collections`, `/datastore/sources/:id`, etc.).
   - For tabbed lists, every tab variant (`?tab=servers`, `?tab=connectors`, …).
   - For resources with detail pages, sample one representative ID from `mock-data/tables/`.
3. **For each route:** `preview_eval` to navigate, `preview_snapshot` to read the accessibility tree (preferred — text + roles + structure), `preview_screenshot` only when layout/style verification is needed. Skip `preview_inspect` unless a token-level CSS check matters.
4. **Compare** the rendered UI against the spec, applying the **triangulation matrix** above:
   - **Tabs / sections present in prototype but absent in spec** → spec stale (functional drift, code wins).
   - **Filter pills, toolbar controls, columns, badges in prototype but undocumented** → spec stale.
   - **Detail-page tabs / actions in prototype but undocumented** → spec stale.
   - **Spec describes a UI element not rendered** → either prototype regression (raise as drift on prototype) or spec ahead of code (mark as "spec ahead").
   - **Spec uses a pattern that contradicts what renders** (e.g., spec says drawer, code renders route) → spec stale; trust code.
   - **Code renders a feature not traceable to any PDD feature** → **WARN**. Don't silently document. Ask user whether to backfill PDD (`/inspire-feature create`) or remove the feature from code.
   - **Code violates a canonical pattern / component / UX ADR** (drawer for detail, dark mode, module dashboard, `/{module}/settings`) → flag as **code regression**, not spec drift. Suggest `/inspire-prototype` to bring code back in line. Skill rules win here.
5. **Reverse drift findings** are reported separately from forward drift, with severity:
   - **Important** — entire feature/tab/section in code missing from spec.
   - **Minor** — column, label, badge, breadcrumb, toolbar pill missing or mislabeled in spec.
6. **Resolution recommendation** — every reverse-drift finding suggests `/inspire-ui {validate|migrate} {module}` to update the spec, NOT `/inspire-prototype` (the prototype is already correct). The spec catches up to code, not the other way around.

#### Reporting format

```markdown
## Reverse drift (code ahead of spec)

### Important
- [{module}/{screen}] Prototype renders {feature} at {route}, spec doesn't mention it. Update spec to document. Source: live preview {date}.

### Minor
- [{module}/{screen}] Toolbar at {route} has filter pill "{label}" not documented in spec.
```

#### When NOT to browse

- The screen is marked "not implemented yet" — there's nothing to compare.
- The route requires authentication / tenant state the preview can't reach.
- The audit is scoped to a sub-pattern or component, not a route — no preview equivalent.

#### Caching note

Preview snapshots are point-in-time. Re-run navigation after every prototype change. Don't trust an audit's reverse-drift findings older than the working session.

### Cross-screen coherence checks

- All `toolbar-list` instances in a module share toolbar UX (filter pill positions, search placement).
- All `resource-detail` instances in a module share tab ordering (Overview first, Settings last).
- Similar resources across modules (users, agents, collections, filesystems) share status vocabulary.

(Pattern selection rules — toolbar-list vs faceted-list, routes vs drawers — covered under Rules below.)

## After modifying a screen spec — propagation check

Whenever a `create` / `update` / `migrate` / `extract` action changes a screen file in a way that affects the UI (new pattern, new slot, renamed data source, added/removed section, new/removed tab, etc.), the skill MUST explicitly ask the user whether to propagate the change to the prototype before ending the turn.

### Protocol

1. **Detect prototype target.** Read the screen's `## Prototipo actual` section. If it names a `.jsx` file:
   - The file is the propagation target.
   - Also check its "Drift a resolver" list — the spec edit may have already resolved some items or added new ones.
2. **Classify the change.**
   - **Structural** (new pattern instance, new tab, new slot, moved section, changed data source/hook, removed feature): propagation is strongly recommended.
   - **Cosmetic or editorial** (wording, reordered bullets, typo, clarification): propagation usually not needed — the prototype already reflects the intent. Mention it but don't insist.
   - **No prototype declared** (screen marked "not implemented yet" or no file named): skip propagation, but note in the summary that when the prototype lands, this spec is ready.
3. **Ask, don't assume.** Close the turn with a clear question to the user, e.g.:

   > La UISpec de `{module}/{screen}` ha cambiado: {resumen de cambios}. El prototipo `{path}.jsx` queda desalineado con: {lista de drift nuevo}.
   > ¿Propago ahora con `/inspire-prototype`, o prefieres hacerlo en otro turno?

   Offer the user the choice — don't invoke `/inspire-prototype` silently.
4. **If user confirms** (`sí`, `propaga`, `adelante`, etc.): invoke `/inspire-prototype` with a concrete prompt that references the updated screen spec and the specific drift items to resolve.
5. **If user declines or defers:** create a tracker ticket via `/inspire_workspace task create "{summary}" --epic {module}` so it doesn't get lost, and end the turn.

### When NOT to ask

- The edit is purely to the UISpec's own metadata (e.g., fixing a wikilink, adding a PDD feature reference that doesn't change visible UI).
- The target prototype is explicitly flagged as "not implemented yet" in the screen.
- The user already stated in the same turn that they will handle the prototype separately.

## When migrating a legacy monolith (`UISpec_{Module}.md`)

Legacy files (1000+ lines) need to be split into the new structure:

1. **Read the monolith.** Identify screens.
2. **Create `{module}/_index.md`** — consolidate the nav, route map, and feature coverage sections.
3. **Create one screen file per logical grouping.** Apply the granularity rule (~300 lines).
4. **Extract colors/typography/layout duplication** — if it matches `design-system.md`, remove from the module spec. Only keep module-specific overrides.
5. **Replace ASCII layouts** with references to patterns (`**Pattern:** [[../patterns/resource-detail]]`). Keep ASCII only if truly bespoke.
6. **Replace inline mock data** with references to mock-data tables.
7. **Delete the monolith** once every screen has been migrated and the `_index.md` is complete.

## When adding a new pattern or component

New patterns require evidence:

- **Pattern:** appears in >=2 actual screens (or will appear in >=2 planned screens)
- **Component:** appears in >=2 pages (or >=3 if trivial)

Process:

1. Draft the pattern/component file in `patterns/` or `components/`
2. Document: purpose, API/slots, structure (textual, no ASCII), variants, instances
3. If the underlying React component doesn't exist yet, mark state as `To-extract` and list the pages that will adopt it
4. Update `patterns/_index.md` or `components/_index.md`
5. If an existing pattern needs a new variant, update the pattern file's "Variantes" section rather than creating a new pattern

## Rules

1. **PDD is the source of truth for features.** Every screen traces to one or more PDD features.
2. **design-system.md is the source of truth for tokens.** No module redefines colors, typography, density.
3. **patterns/ is the source of truth for screen structure.** Screens instantiate; they don't redescribe.
4. **components/ is the source of truth for shared UI.** Screens reference; they don't redefine.
5. **Screens are lightweight.** Aim for <300 lines. If a screen file grows, extract sub-patterns or components.
6. **No ASCII art for common layouts.** Patterns describe layouts textually. ASCII only in bespoke cases.
7. **No inline mock data.** Reference tables from `mock-data/tables/`.
8. **No historical language.** Specs describe the present.
9. **Route convention.** `/{module}/...` in console, nested routes for detail/edit/new.
10. **Validate before merge.** Run `/inspire-module review` before any PR that modifies UISpec files.
11. **Audit/activity log screens live in `audit/`** (per [[adr-audit-01-centralized-logging]]). A module cannot own screens that display, filter, or stream audit events. Allowed: a dashboard widget or link that points to `/audit/logs?module={module}` or `/audit/logs?actor.id={id}`. Forbidden: a dedicated `audit.md` / `activity.md` screen in a non-audit module, or a sidebar entry "Audit Trail" under a non-audit module. When validating a new or existing screen, flag any of these patterns.
12. **Module landing `/{module}` is a list (or tabbed page), never a dashboard** (per [[adr-ux-01-module-landing-pages]]). Forbidden: `dashboard.md` screen routed as `/{module}`, sidebar entry "Dashboard"/"Overview" pointing to `/{module}`, prototype `{Module}Dashboard.jsx` component rendered at `/{module}`. Allowed: dashboards scoped to a specific resource (`/{module}/{resource}/:id/analytics`) or to a subsystem with its own semantics. When validating, flag any module-level dashboard. When creating a new module, the landing MUST be `<Navigate to="/{module}/{primary-list}" replace />` or a tabbed page.
13. **Settings live inside the primitive, not as a module-level page** (per [[adr-ux-02-settings-location]]). Forbidden: `settings.md` routed as `/{module}/settings`, sidebar entry "Settings" under a functional module, prototype `{Module}Settings.jsx` as a dedicated page. Allowed: a "Settings" tab inside the primitive's own screen (e.g., `/ai-agents/models?tab=settings`), or cross-module settings under Platform (`/platform/notifications`, `/platform/organization`, etc.). Platform module is the sole exception — its sidebar label is literally "Settings" at top level. When validating, flag any functional module's `/settings` route or sidebar entry.
14. **Propagation check after spec edits.** Ask the user before ending the turn whether to propagate visible UI changes to the prototype. Full protocol in "After modifying a screen spec".

## Skill invocations

- `/inspire-ui create {module}/{screen}` — scaffold a new screen file with pattern selection
- `/inspire-ui validate {module}/{screen}` — validate a single screen against patterns/components, browsing the prototype when preview is available to detect reverse drift
- `/inspire-ui migrate {module}` — migrate a legacy `UISpec_{Module}.md` monolith to the new structure
- `/inspire-ui extract {pattern|component} {name}` — promote a recurring UI block to a shared pattern or component
- `/inspire-ui audit {module}` — scan a module's screens for forward + reverse drift, duplication, extraction opportunities. Browses the running prototype when available.
