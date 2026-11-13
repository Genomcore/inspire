# Module — review
> Part of [inspire-module](../SKILL.md). Read when the entry's index routes here.

## Subcommand: review

Runs all consistency checks for the module. This is the **required gate before any
PR** that modifies the module's hub
(`inspire_kb/01_spec/_modules/{module}/{module}.module.md`) or any file under the
module's directory.

### 1. Module hub + features structure

**Hub (`{module}.module.md`):**
- Exists — exactly one `*.module.md` in the module's directory (the file *is* the
  module).
- Is a **pure hub**: overview, relationships to other modules, and links. **No full
  use-case bodies inline.**
- **Its links match the module.** `## Use cases` links every `*.feature.md` under
  the module's directory; `## Domain` every `*.entity.md` and `*.action.md`;
  `## Module ADRs` every `*.adr.md` in its `_adr/`; `## Screens` every
  `*.screen.md`, in any face, that declares `module: {module}` or binds one of its
  actions. A file the hub does not link, or a link to a file that does not exist, is
  a finding.

**Use-case files (`_features/`):**
- One file per use case (`{use-case}.feature.md`); each carries a back-link to the
  hub `[ModuleName](../{module}.module.md)` in its intro.
- Feature / use-case IDs are unique within the module and use the module's ID
  prefix (declared in the hub / the project's `00_bootstrap` conventions).

### 2. screen spec structure

The module's screens are the ones its hub links: they live in the faces that show
them (`_faces/{face}/_screens/{slug}.screen.md`), found by extension, never in the
module's directory. Each face's `_index.md` is that face's navigation and belongs to
`/inspire-screens`; routes are derived, never written into it.

- Every screen carries its identity block (`id` (`{face}.{slug}`) · `module` ·
  `screen` · `lifecycle`), a `**Features:**` line, a non-empty `## Purpose` and a
  non-empty `## Bindings`. A `**Pattern:**` line is optional; where it is there, it
  resolves to a `*.pattern.md` in `inspire_kb/01_spec/_design-system/patterns/` and
  that pattern's required regions find the bindings they need.
- A screen binds only actions its face's bundles expose (`face-exposure.sh`).
- No screen redefines design tokens (those live in `_design-system/` and the face's
  `{face}.tokens.json`); no inline mock data (reference the data source); each screen
  stays focused (~250 lines).

### 3. Quality checks

- **The writing contract holds** — R1–R6 of
  [`_references/writing-style.md`](../../_references/writing-style.md), R6 (present
  state, never history) above all. The closed token list and its section-scoped
  exemptions live there.
- No embedded ADR content (>~10 lines of rationale without an ADR link).
- Every link is a relative Markdown link ([kb-links.md](../../_references/kb-links.md)) whose path names an existing file: design-system entries (`*.pattern.md`,
  `*.layout.md`, `*.component.md`, `design-system.md`), ADRs at every scope, and the
  screens in every face. A link whose target is missing is fixed by creating the
  target in draft (rule 3 of [`../SKILL.md`](../SKILL.md)).

### 4. Cross-layer coverage

- **Features ↔ screen spec:** every feature with UI implications has a screen in
  each face of its blast radius; every screen's `**Features:**` line references
  features that exist (`*.feature.md`).
- **Features ↔ Prototype:** features meant to appear in the horizontal prototype
  are reflected at the prototype root (`/prototype` by default — resolve
  `prototype_root` per
  [`_references/product-roots.md`](../../_references/product-roots.md), and treat
  `none` as "no prototype to check"), and what building them taught has landed in
  the specs / screens / ADRs (the horizontal keeps no learnings file).
- **Features ↔ Specs:** every feature that describes a behavior has at least one
  realizing action descriptor in the module's `_domain/` (flag gaps as
  `important`); every action's `## Purpose` back-sources to a feature via
  link (flag orphan actions as `important`).
- **ADR alignment:** flag anything that contradicts a **current** ADR — one present
  and not superseded or rejected — within its maturity's reach: the global ADRs, the
  module's own `_adr/`, and the `_adr/` of every face whose screens use the module. Flag it whatever the narrower artifact says: a module hub, a
  use case and a descriptor have nowhere to declare an ADR departure, so the
  contradiction is drift and the departure belongs in a superseding or amended ADR
  ([`_references/authority.md`](../../_references/authority.md) § A2).

### 5. Spec-layer (SDD) checks

Run `.inspire/bin/review.sh inspire_kb/01_spec/_modules/{module}/` and incorporate
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
- Hub links: {ok | N out of sync}

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
