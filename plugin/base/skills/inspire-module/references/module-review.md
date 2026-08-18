# Module — review
> Part of [inspire-module](../SKILL.md). Read when the entry's index routes here.

## Subcommand: review

Runs all consistency checks for the module. This is the **required gate before any
PR** that modifies the module's hub (`inspire_kb/02_modules/{module}.md`) or its
files under `inspire_kb/03_features/{module}/`.

### 1. Module hub + features structure

**Hub (`02_modules/{module}.md`):**
- Exists — one file per module (the file *is* the module's entry in `02_modules/`).
- Is a **pure hub**: overview, relationships to other modules, and links to
  the module's screens, specs, spikes and module-scoped ADRs. Its use cases live
  in `03_features/{module}/` — the glob is the index. **No full use-case
  bodies inline.**
- **Legacy check:** a hand-maintained use-case index block still sitting in the
  hub is operator-owned; suggest removing it on next touch — never auto-edit it.

**Use-case files (`03_features/{module}/`):**
- One file per use case (`{use-case}.md`); each carries a back-link to the hub
  `[[../../02_modules/{module}|ModuleName]]` in its intro.
- Feature / use-case IDs are unique within the module and use the module's ID
  prefix (declared in the hub / the project's `00_bootstrap` conventions).

### 2. screen spec structure

- Folder location follows the shape of the screens tree, which
  [`_references/surface-scope.md`](../../_references/surface-scope.md) keys to the
  roster: `inspire_kb/05_screens/{module}/` while the suite has at most one UI
  surface; `05_screens/{surface}/{module}/` plus `05_screens/shared/{module}/`
  once it has two or more. Each such folder carries `_index.md` + one file per
  screen.
- `_index.md` contains the route map + feature-coverage table; every screen in
  the map exists on disk, and every screen file is referenced in the map.
- Every screen header carries `**Features:**` and `**Pattern:**`; every pattern
  resolves to a file in `inspire_kb/05_screens/patterns/` (or `bespoke` with
  justification).
- No screen redefines design tokens (those live in `design-system.md`); no inline
  mock data (reference the data source); each screen stays focused (~250 lines).

### 3. Quality checks

- **The writing contract holds** — R1–R6 of
  [`_references/writing-style.md`](../../_references/writing-style.md), R6 (present
  state, never history) above all. The closed token list and its section-scoped
  exemptions live there.
- No embedded ADR content (>~10 lines of rationale without an ADR link).
- All `[[wikilinks]]` resolve (including cross-folder: `patterns/`, `components/`,
  `01_adr/`, `design-system.md`).

### 4. Cross-layer coverage

- **Features ↔ screen spec:** every feature with UI implications has a screen; every
  screen's `**Features:**` line references features that exist in `03_features`;
  the screen spec `_index.md` coverage table aligns with the actual screens.
- **Features ↔ Prototype:** features meant to appear in the horizontal prototype
  are reflected at the prototype root (`/prototype` by default — resolve
  `prototype_root` per
  [`_references/product-roots.md`](../../_references/product-roots.md), and treat
  `none` as "no prototype to check"), and what building them taught has landed in
  the specs / screens / ADRs (the horizontal keeps no learnings file).
- **Features ↔ Specs:** every feature that describes a behavior has at least one
  realizing action descriptor in `inspire_kb/04_domain/{module}/` (flag gaps as
  `important`); every action's `## Purpose` back-sources to a feature via
  `[[wikilink]]` (flag orphan actions as `important`).
- **ADR alignment:** flag anything that contradicts a **current** ADR — one present
  and not superseded or rejected — within its maturity's reach (see
  `inspire_kb/01_adr/`).

### 5. Spec-layer (SDD) checks

Run `.inspire/bin/review.sh inspire_kb/04_domain/{module}/` and incorporate
findings. The rule set covers:
- `acyclic-deps` — no cycles or self-loops in the `requires` graph
- `stable-blockers` — stable actions don't require non-stable targets
- `touched-entity-lifecycle` — stable actions touch only entities ≥ accepted
- `entity-coherence` — per-field type-conflict, unsourced, and orphan-write findings

Render findings via the shared format at
[`.claude/skills/_references/findings-format.md`](../../_references/findings-format.md).
Do not inline a re-spec.

### 6. Drift consolidation

Screen files carry `## Current prototype` sections with drift items. Consolidate:
count total items, group by type (component adoption, data wiring, gap, ADR
alignment), and report a summary. Priority: ADR alignment > data wiring >
component adoption > cosmetic.

### 7. Overengineering detection

- UI/patterns used in <2 screens and not in the catalog / not justified as
  bespoke.
- Prototype screens with no screen spec and no feature justification.

### Output format

```markdown
# Module Review: {module} | {date}

## Summary
- Use cases: {count}
- Screen files: {count}
- Drift items pending: {count}
- Issues: {critical} critical, {important} important, {minor} minor

## Module hub + features
- Use-case files: {list}
- Sub-layer sync: {ok | N drifted}

## screen spec Structure
- Pattern usage: {list} | {bespoke count}
- Component usage: {list}

## Critical
- [{module}] {description} — {file}:{line} | Fix: `/{skill}`

## Important / Minor
- ...

## Drift Summary / OK
- ...
```
