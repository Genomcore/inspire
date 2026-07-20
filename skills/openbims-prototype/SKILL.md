---
name: openbims-prototype
description: "Implement and maintain React prototypes for OpenBIMS Console and Marketplace Console. Use when building screens from UI specifications, adopting shared components, or refactoring to pattern-driven structure."
---

# /openbims_prototype — React Prototypes

## When to use

- Implementing a new screen from a UISpec screen file
- Adopting canonical shared components (migrating pages from inline implementations)
- Updating an existing prototype page to match updated UISpec
- Adding or modifying data hooks
- Resolving the "Drift a resolver" items listed in UISpec screen files

## Context: the prototype is an interactive mockup

The prototype is NOT the production application. It's an interactive visualization of product design decisions — closer to "Figma with data". It uses DuckDB-WASM with mock JSONL data, not a real backend.

The dev server CAN be launched from this environment:

```bash
cd code/openbims-console && npm run dev   # port 5173
cd code/marketplace-console && npm run dev # port 5174
```

## How to implement a screen from a UISpec

Starting a new (or updated) screen involves reading four layers of spec:

1. **UISpec screen file** — `spec/specs/ui/openbims-console/{module}/{screen}.md`. This is the source of truth for what to build. It declares:
   - Features covered (PDD IDs)
   - Pattern instantiated
   - Data sources (tables and hooks)
   - Slots filled in from the pattern
   - Components referenced
   - "Prototipo actual" section with current `.jsx` path and "Drift a resolver"

2. **Pattern file** — `spec/specs/ui/openbims-console/patterns/{pattern}.md`. Describes the structural pattern the screen instantiates. Read this to understand layout, slots, behavior.

3. **Component files** — `spec/specs/ui/openbims-console/components/{component}.md`. Describe the React components to use. Each has its API, state (implemented/to-extract), and location.

4. **Design system** — `spec/specs/ui/openbims-console/design-system.md`. Tokens, colors, typography, density. Do NOT redefine these in any page.

## Project structure

### OpenBIMS Console (`code/openbims-console/`)

```
src/
├── App.jsx                       # All routes — every page must be imported and routed here
├── components/
│   ├── ui/                       # shadcn primitives (Button, Card, Badge, Input, ...) — never duplicate
│   ├── shared/                   # Cross-module canonical components
│   │   ├── StatusDot.jsx         # canonical status indicator with ~40 status keys
│   │   ├── ArtifactIcon.jsx      # SVG-from-path icon with fallback
│   │   ├── PageHeader.jsx        # canonical page header (icon + title + meta + actions + back)
│   │   ├── TabStrip.jsx          # canonical tabs (hand-rolled border-b-2) with URL sync
│   │   ├── StatCard.jsx          # KPI card with delta/trend
│   │   ├── FilterPills.jsx       # row of filter pills (supersedes ToolbarPill, Pills, SourceFilter)
│   │   ├── FacetSidebar.jsx      # sidebar of facet groups for list pages
│   │   ├── CopyableId.jsx        # monospaced ID with copy-to-clipboard feedback
│   │   ├── FavStar.jsx           # favorites toggle + useFavorites hook with localStorage
│   │   ├── EmptyState.jsx        # centered empty state with CTA
│   │   ├── LoadingState.jsx      # canonical loading (+ ErrorState named export)
│   │   ├── Breadcrumb.jsx        # for deep hierarchies only
│   │   └── FileContextMenu.jsx   # specific to filesystem module
│   └── layout/                   # TopBar, Sidebar, Layout
├── modules/
│   └── {module}/
│       ├── pages/*.jsx           # One file per page/route
│       └── data/*.js             # Static data helpers (non-DuckDB helpers only)
├── db/
│   ├── client.js                 # DuckDB-WASM init
│   ├── useQuery.js               # low-level query hook
│   ├── context.js                # DuckDB React context
│   └── hooks/                    # domain hooks: useAgents, usePrompts, useSkills, ...
│       └── index.js              # re-exports
└── lib/
    ├── utils.js                  # cn() helper
    └── duckdb-array.js           # safeParseArray/toArray for VARCHAR[] columns
```

### Marketplace Console (`code/marketplace-console/`)

Separate project, own router. Routes: `/admin/*` + `/publisher/*`. Lazy-loaded with `LazyRoute`.

## Canonical shared components — use them, don't reinvent

The following shared components are **canonical**. Before writing inline JSX that does something similar, import the shared one.

| Need | Component | Spec |
|------|-----------|------|
| Page header with icon + title + meta + actions + optional back link | `PageHeader` | [[components/page-header]] |
| Horizontal tabs under a header | `TabStrip` (with `searchParam: 'tab'` for URL sync) | [[components/tab-strip]] |
| Status indicator (dot + optional label) | `StatusDot` | [[components/status-dot]] |
| KPI card in a dashboard or list top | `StatCard` | [[components/stat-card]] |
| Toggle pill (e.g. ★ Favorites) | `ToolbarPill` | [[components/toolbar-pill]] |
| Single-select filter/sort pill | `DropdownPill` | [[components/dropdown-pill]] |
| Row of filter pills (obsoleto: usa `DropdownPill` en toolbars de listas) | `FilterPills` | [[components/filter-pills]] |
| Sidebar of facet groups for **marketplace** browsing | `FacetSidebar` + `FacetGroup` | [[components/facet-sidebar]] — not for module lists |
| Monospaced ID with copy button | `CopyableId` | [[components/copyable-id]] |
| Favorites star toggle | `FavStar` + `useFavorites(storageKey)` | [[components/fav-star]] |
| Resource icon (SVG with fallback) | `ArtifactIcon` | [[components/artifact-icon]] |
| Empty list / section placeholder | `EmptyState` | [[components/empty-state]] |
| Async state loading | `LoadingState` | [[components/loading-state]] |
| Async state error | `ErrorState` (exported from LoadingState.jsx) | [[components/loading-state]] |

### Standard async page template

Every page that consumes a DuckDB hook should follow this pattern:

```jsx
import LoadingState, { ErrorState } from "@/components/shared/LoadingState"
import EmptyState from "@/components/shared/EmptyState"

export default function MyPage() {
  const { data, loading, error, refetch } = useMyHook()
  if (loading) return <LoadingState message="Loading..." />
  if (error) return <ErrorState message={error.message} retry={refetch} />
  if (!data || data.length === 0) return <EmptyState title="No items yet" ... />
  // main content
}
```

### DuckDB-WASM type quirks — always coerce

DuckDB-WASM returns column values with types that **don't always match the SQL schema**. Never pass a DuckDB value directly to APIs that assume a specific JS type. Use the helpers from `@/lib/duckdb-array`:

```jsx
import {
  safeParseArray,   // VARCHAR[] → real JS array
  coerceString,     // any → string (safe for localeCompare, toLowerCase, etc.)
  coerceDate,       // string | Date | number | bigint → Date | null
  formatDateISO,    // any → "YYYY-MM-DD" (or "—" if null)
  formatRelative,   // any → "3d ago" / "2h ago" / ISO date (or "—")
} from "@/lib/duckdb-array"
```

**Why this matters (real bugs hit):**

- `VARCHAR` columns (like `updated_at`) can come back as **non-string** values. Calling `row.updated_at.localeCompare(...)` throws `TypeError: ... is not a function`. Always wrap: `coerceString(row.updated_at).localeCompare(...)`.
- `TIMESTAMP` columns can come back as `BigInt` in microseconds. `new Date(bigint)` throws. Use `coerceDate(row.ts)`.
- `VARCHAR[]` comes as JS array / JSON string / Postgres literal `{a,b,c}`. Use `safeParseArray`.

**Rule:** when a page consumes a DuckDB column value, assume the type is opaque. Run it through the appropriate coerce helper **before** any method call or arithmetic. Do NOT write inline `safeParseArray`/`coerceDate` helpers — extend the lib if you need a new coercion.

### Hook return-value pitfalls

Functions returned by custom hooks are **new references on every render** unless explicitly memoized by the hook itself. Never use a hook-returned function as a `useMemo` / `useEffect` / `useCallback` dependency — it causes an infinite render loop that tears down the entire React tree (build passes, but preview shows a blank `#root`).

```jsx
// ❌ WRONG — isFav is redeclared every render → loop
const { isFav } = useFavorites("agents")
const filtered = useMemo(() => list.filter(x => isFav(x.id)), [list, isFav])

// ✅ RIGHT — depend on the array / primitive
const { favorites } = useFavorites("agents")
const favSet = useMemo(() => new Set(favorites), [favorites])
const filtered = useMemo(() => list.filter(x => favSet.has(x.id)), [list, favSet])
```

Same for any hook that returns callbacks (e.g., `refetch`, `toggle`, `setState`): depend on the underlying state/data, not the function.

### Verify in preview, not just `npm run build`

The build only catches syntax errors. Runtime issues that still let the build pass:

- Infinite render loops (`useMemo` depending on unstable refs).
- Type errors from DuckDB values (`localeCompare is not a function`, `Invalid Date`).
- Null dereferences on optional fields.
- **Silent `Edit` no-ops after multi-Edit removals** — see below.

After every prototype change, **open `/preview` and visit the route**. If `document.querySelector('#root').children.length === 0`, the page crashed — inspect `window.__errors` via `preview_eval` with an `error` listener installed before navigation.

### Silent Edit no-ops after multi-Edit refactors

When a refactor removes code across multiple `Edit` calls to the same file (e.g. remove a drawer component + its render site + its helpers), occasionally an `Edit` will report `"updated successfully"` but leave the file unchanged — typically because the `old_string` had a subtle whitespace / newline / trailing-comment difference from the actual file content. Since the removed code is itself syntactically valid React, `npm run build` passes happily. The page then crashes at runtime with `ReferenceError: <removedSymbol> is not defined` and shows a blank `#root`.

**Verification recipe after any removal refactor:** before running `npm run build`, grep the file for the symbols you removed:

```
Grep -n "RemovedComponent|removedState|removedHelper" {path}
```

Expected output: **no matches**. If matches remain, the removal didn't apply — re-Edit (often a cleaner match with a larger `old_string` block fixes it) or rewrite the file with `Write`.

**When to suspect this specifically:** multi-Edit refactor that removes a declared-and-used symbol (state, imported name, local component) + `npm run build` passes + preview shows blank `#root` + `preview_console_logs` reports `An error occurred in the <X> component` or `ReferenceError: Y is not defined`. The diagnostic grep is ~1 second; run it before launching the server.

## Platform UX conventions (read before implementing a list or detail)

- **Module list pages use the toolbar pattern** (compact header + tabs + horizontal filter dropdowns + dense table + status bar). Reference: `code/openbims-console/src/modules/datastore/pages/Collections.jsx`. See [[../spec/specs/ui/openbims-console/patterns/toolbar-list]]. Do **not** render a left `FacetSidebar` on module lists.
- `FacetSidebar` is reserved for Marketplace-style browsing screens. If a new list page pulls it in, stop and re-read the screen spec — you're probably using the wrong pattern.
- **Detail screens are routes.** When a row in a list is clicked, `navigate('/{module}/{resource}/:id')`. The detail page renders full-width with [[components/page-header]] + back link. Drawer overlays, `?detail=<id>` query params, and inline `<XDrawer />` sub-components are not the platform default — only use them if the user explicitly asks.
- **Canonical main-page header** (apply uniformly to every submodule landing page):
  - `PageHeader` with `icon` + `title` + `subtitle` (left). **No counts, pills, stats, or badges next to the title.**
  - Right side via `PageHeader` props: `docsHref="/docs/module/<id>"` (required), `search={{ value, onChange, placeholder }}` if filterable, `actions={<>…</>}` for `[+ New]` / `[Import]` etc.
  - **Never render `<StatCard>` on a main page** unless the user explicitly asks. Dashboards go in dedicated dashboard screens.
- **Tabs convention:** `TabStrip` below the header. Each `tab.count` is shown. `tab.align: "right"` for Settings. `tab.tone: "violet"` for Marketplace. Marketplace is always a tab, never a standalone button.
- **Search is in the header, not in the toolbar.** The toolbar under the tabs carries filter dropdowns, sort, per-view actions only.
- **Toolbar canon = pills.** Filters are `DropdownPill`, toggles are `ToolbarPill`, sort is a `DropdownPill` with `icon: ArrowUpDown` and `showAll: false`. **Do not** introduce native `<select>`, `FilterPills`, or bespoke toolbar layouts on module lists. Reference: `AIAgentsList.jsx` and `CollectionsTab`.
- **Status dot is inline, not a column.** When a list has a status, render `<StatusDot status={row.status} />` (no label) in a narrow unlabelled cell right after Favorites and before the row's icon/name. The `StatusDot` exposes the label via native `title` tooltip when `showLabel` is false. Do not add a "Status" column with header text. If the list has a status dot, the **Status filter must be the first `DropdownPill`** in the toolbar (after Favorites).
- **Lists render as `<table>`**, not as `<div>` grids of custom rows. Exceptions require explicit user approval.
- **Full-height flex layout for main list pages.** The outer container is `<div className="flex flex-col h-[calc(100vh-56px)]">`. Inside it:
  1. `shrink-0 px-6 pt-5 pb-3` for `PageHeader` (with `className="mb-0"`).
  2. `<TabStrip className="shrink-0 px-6" />` pegado al header.
  3. `shrink-0 px-6 py-1.5 border-b border-slate-100 bg-slate-50/50 flex items-center gap-1.5 flex-wrap` for the toolbar strip.
  4. `flex-1 overflow-y-auto` wrapping the `<table>` with `sticky` thead. **No `<Card>` wrapper around the table** — edge-to-edge is the canon.
  5. `shrink-0 border-t border-slate-200 px-6 py-1.5 bg-slate-50 text-[11px] text-slate-500 flex items-center justify-between` for the status bar footer.
- Tabs with non-tabular content (Settings form, Marketplace placeholder) render inside `<div className="flex-1 overflow-y-auto px-6 py-6">`.
- Reference: `AIAgentsList.jsx` + `CollectionsTab`.

## Rules

1. **UISpec is the source of truth.** Implement what the screen file says — no extra dashboards, charts, tabs, or features "for completeness". If you think something is missing, update the UISpec first.
2. **Check before creating.** Before writing any new component:
   - Is it in `src/components/ui/` (shadcn)?
   - Is it in `src/components/shared/` (canonical)?
   - Is it in another `src/modules/{other}/pages/` that could be extracted?
3. **Routing:** All routes in `App.jsx`. Pattern: `/{module}/*`. Navigation in `Sidebar.jsx`. Every `.jsx` page MUST be imported and routed — no dead files. **Every detail screen has its own route** (`/{module}/{resource}/:id`). Clicking a list row = `navigate('/{module}/{resource}/:id')` — never a drawer overlay. Drawers are not a supported UX pattern; don't introduce them unless the user explicitly asks.
4. **Imports:** Use `@/` alias (`= src/`). Cross-module imports: `@/modules/{other}/pages/...`. Never relative paths.
5. **Data via hooks.** Use `src/db/hooks/useXxx.js` for DuckDB queries. Do NOT inline SQL in page components (exception: ad-hoc diagnostics — never committed).
6. **Icons:** Artifact icons live in `public/icons/*.svg`, rendered via `ArtifactIcon`.
7. **Styling:** Tailwind utility classes only. Light mode. Color tokens per [[../spec/specs/ui/openbims-console/design-system]]:
   - `teal-600` primary
   - `violet-600` AI/CORA
   - `green-500` success, `amber-500` warn, `red-500` error, `slate-*` neutral
   - (Old "yellow" is NOT canonical — use `amber-500`.)
8. **Status indicators:** use `<StatusDot status="..."/>`. If your status key isn't in the map, add it to `StatusDot.jsx` — don't inline a `statusColors` map.
9. **No dead components.** Every `.jsx` must be imported and routed.
10. **Follow "Drift a resolver".** When opening a screen file to modify it, read its `## Prototipo actual` section and resolve pending drift items as part of the PR if they're trivial (component adoption). Note larger drift in the commit message.
11. **Propagation check after prototype edits.** When a change affects visible structure/behavior that the UISpec describes, explicitly ask the user before ending the turn whether to propagate to the UISpec via `/openbims_ui`. Don't assume — offer the choice. If declined, track the drift via `/openbims_workspace task create "..." --epic {module}`. See "After modifying the prototype — propagation check" above for the full protocol. This is symmetric with the equivalent rule in [[openbims-ui/SKILL|/openbims_ui]].
12. **Coerce DuckDB values.** Before calling any string/number/date method on a DuckDB column value, route it through `coerceString` / `coerceDate` / `safeParseArray` from `@/lib/duckdb-array`. DuckDB-WASM's return types don't always match the SQL schema — see "DuckDB-WASM type quirks" above for the rationale.
13. **Never use hook-returned functions as deps.** Depend on the underlying state (array, string, number), not on a function the hook returned — functions are new references every render and will trigger infinite loops. See "Hook return-value pitfalls" above.
14. **Always open preview after a prototype change.** `npm run build` only catches syntax. Runtime errors (type mismatches, render loops) produce a blank page. Visit the affected route in preview and verify `#root` is not empty before declaring the change done.
15. **Propose captures after fixing bugs.** When a fix suggests a reusable pattern (lib helper, skill lesson, canonical component), surface it to the user at end of turn — don't silently edit the skill or catalog, and don't let the insight evaporate. See "After fixing a bug — capture the learning" for the protocol.

## After modifying the prototype — propagation check

Whenever a prototype edit changes **visible behavior or structure** that the UISpec describes (new tab, changed data source/hook, added/removed section, different pattern instance, renamed route, different canonical component adoption, etc.), the skill MUST explicitly ask the user whether to propagate the change back to the UISpec before ending the turn.

This is the inverse of the protocol in `/openbims_ui` — the principle is bilateral per [[CLAUDE.md]]: if a change affects a layer, that layer must be updated.

### Protocol

1. **Identify the UISpec target.** From the prototype file path, derive the screen: `code/openbims-console/src/modules/{module}/pages/{Component}.jsx` maps to `spec/specs/ui/openbims-console/{module}/{screen}.md`. Read that screen to see what it currently says.
2. **Classify the change.**
   - **Structural** (new tab, changed data hook, new widget, changed canonical component, route change): propagation to UISpec is strongly recommended.
   - **Cosmetic or implementation-only** (refactor, imports reorder, micro-styling, bug fix that doesn't change described behavior): propagation usually not needed. Mention but don't insist.
   - **Resolves existing drift** (the change closes an item in the screen's "Drift a resolver" list): update that section at minimum — always.
   - **No spec exists** (legacy monolith still active, or the screen was never spec'd): skip propagation but note the gap so it surfaces in the next `/openbims_ui migrate` or `/openbims_module review`.
3. **Ask, don't assume.** Close the turn with a clear question to the user, e.g.:

   > He modificado `{path}.jsx`: {resumen de cambios}. La UISpec `{module}/{screen}.md` está desalineada en: {items}.
   > ¿Actualizo la UISpec ahora con `/openbims_ui`, o prefieres hacerlo en otro turno?

   Offer the user the choice — don't invoke `/openbims_ui` silently.
4. **If user confirms:** invoke `/openbims_ui` with a concrete prompt (target screen + specific updates to apply). At minimum, update the screen's `## Prototipo actual` "Drift a resolver" to remove resolved items and add any new ones.
5. **If user declines or defers:** create a tracker ticket via `/openbims_workspace task create "{summary}" --epic {module} --size {S|M|L}` so the spec/prototype gap doesn't get lost, and end the turn.

### When NOT to ask

- Pure bug fixes where the described behavior was already correct and the prototype was wrong.
- Internal refactors (splitting a function, reorganizing imports, renaming a local variable) with no user-visible change.
- The user already stated in the same turn that they will update the UISpec separately.
- The screen doesn't exist yet (legacy UISpec monolith pending migration).

## After fixing a bug — capture the learning

Prototype bugs often reveal a **class of problem** that will recur in other pages. When you fix a bug, ask yourself: *"Will the next page that does X hit this same issue?"* If yes, don't just fix this instance — propose extracting a lib helper or codifying the lesson in this skill.

### Triggers — when to propose a follow-up

You should proactively surface the opportunity when any of these apply:

- **Pattern repeats across pages.** You wrote an inline helper (date formatter, type coercer, parser, mapper) that other pages will almost certainly need too → propose moving to `@/lib/*`.
- **Runtime error the build didn't catch.** A `TypeError`, infinite loop, `Invalid Date`, or blank `#root` that passed `npm run build` → propose adding the lesson to the skill's pitfalls section so the next invocation doesn't repeat it.
- **Non-obvious API quirk.** DuckDB returning unexpected types, a canonical component having a hidden gotcha, a hook that requires specific dep shape → pitfall section update.
- **Inline JSX that duplicates shared-component intent.** If you find yourself writing something that "feels canonical", propose extracting to `src/components/shared/` with a spec.

### Protocol — how to surface it

After landing the fix (and verifying in preview), **end the turn with a proposal** to the user, not a silent edit. Format:

> **Improvement opportunity detected.** While fixing `{short description}` in `{file}`, I noticed: {pattern / root cause}. This will likely recur in {scope}. Proposed follow-up:
> - **Lib:** extract `{functionName}` to `@/lib/{name}.js` so other pages can reuse it (replaces inline helpers in {places}).
> - **Skill update:** add a "{section name}" entry to `/openbims-prototype` so the next invocation knows to use it.
> - **Component spec:** if UI-shaped — add `spec/specs/ui/openbims-console/components/{name}.md` per `/openbims_ui`.
>
> ¿Aplico ahora, o creo un ticket vía `/openbims_workspace task create` para otro turno?

Offer the choice. Do NOT silently modify the skill, lib, or component catalog — those are workspace-wide artifacts that need the user's awareness.

### Examples (real cases already captured)

- **DuckDB value coercion** → `@/lib/duckdb-array.js` (`coerceString`, `coerceDate`, `formatDateISO`, `formatRelative`) + "DuckDB-WASM type quirks" section above.
- **Hook-returned function refs as deps** → "Hook return-value pitfalls" section above + rule 13.
- **Blank-page build-passes-preview-fails** → "Verify in preview, not just `npm run build`" + rule 14.
- **Silent `Edit` no-ops after multi-Edit removals** (Audit drawer refactor, 2026-04-21) → "Silent Edit no-ops after multi-Edit refactors" section above. Grep-for-removed-symbols is the 1-second check that prevents the blank-page loop.

When a new class of bug appears and isn't covered above, follow the protocol to add it.

## Adopting a canonical component (migration recipe)

When a page still has an inline version of something that's now canonical:

1. Import the canonical component: `import PageHeader from "@/components/shared/PageHeader"`
2. Replace the inline JSX block with the component call, mapping props to the component's API
3. Remove helper functions that the component supersedes (e.g., if you had a local `StatCard`-like block with 4 copies, delete all four and use the component)
4. Keep domain-specific widgets inline (categoryColors, module-specific renderers) — those are NOT canonical
5. Build with `npm run build` to verify no regression
6. Update the screen's "Drift a resolver" list — remove the item you just fixed

## Validation checks

- Every page in `src/modules/{module}/pages/` is imported in `App.jsx`
- Every UISpec screen file has a corresponding page component (or declares "not implemented yet")
- Every page that consumes data uses a hook from `src/db/hooks/` (no inline SQL)
- No inline implementations that duplicate canonical shared components
- All hooks in `src/db/hooks/` are exported from `index.js`
- No pages for eliminated modules
- No dead `.jsx` files

## Related skills

- `/openbims_ui` — before implementing, verify the UISpec screen file exists and is current
- `/openbims_module review` — before PR, review the whole module's consistency
- `/openbims_feature review {feature-id}` — verify a specific feature's prototype coverage
