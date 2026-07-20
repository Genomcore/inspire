---
name: inspire-feature
description: "Lifecycle of a feature / use case: create / review / update / delete a use-case file in a module and propagate across the KB layers. Use when adding, auditing, or removing features."
---

# /inspire_feature — Feature-level Operations

## Scope

A **feature** is a use case, captured as a file
`.inspire_kb/02_features/{module}/{use-case}.md` and listed in that module's
`_index.md`. This skill owns feature-scoped operations and their propagation
across the KB layers: UISpec (`05_ui`), prototype (`03_prototypes` + `/prototype`),
specs (`04_specs`), and ADRs (`01_adr`).

## Invocation

- `/inspire_feature review {feature-id}` — single feature, all layers
- `/inspire_feature review {module}` — batch mode, all features of a module (parallel agents)
- `/inspire_feature create {module}/{feature-id}` — new use-case file + index entry
- `/inspire_feature update {feature-id}` — modify description, dependencies, priority
- `/inspire_feature delete {feature-id}` — remove + orphan checks across layers
- `/inspire_feature scan {feature-id}` — SDD layer alignment for one feature (fast)
- `/inspire_feature scan {module}` — batch SDD layer alignment for all features of a module

## Subcommand: review

### Single feature mode

Reviews one feature across all layers. Runs inline (no agents).

1. **Locate the feature.** Find the use-case file in
   `.inspire_kb/02_features/{module}/`. Read: description, actor/personas,
   dependencies, priority, state, ADRs referenced. Identify the module from the
   folder.
2. **UISpec coverage.** In `.inspire_kb/05_ui/{module}/`, search each screen's
   `**Features:**` line for this feature ID; cross-reference the UISpec `_index.md`
   coverage table. Flag if no screen covers a UI-facing feature; note "No UI
   expected" for backend/infrastructure features.
3. **Prototype coverage.** For each covering screen, verify it is reflected in the
   horizontal prototype at `/prototype`, and note drift (pending component
   adoption, hardcoded data, ADR gaps). Learnings belong in
   `.inspire_kb/03_prototypes/`.
4. **Specs (SDD) coverage.** Find action descriptors whose `## Why` wikilinks back
   to this feature. Search `.inspire_kb/04_specs/**/*.md` for `[[{feature-id}]]`.
   Flag if zero realizing actions exist. For each, report `id`, `lifecycle`, and a
   one-line `## Why` summary.
5. **ADR alignment.** If the feature references an ADR (`[[adr-xxx]]`), verify it
   exists and is `accepted`. Surface prototype drift items that reference
   unimplemented ADR requirements.

**Output format (single):**

```markdown
# Feature Review: {feature-id} · {feature-name} | {date}

## Feature
- File: {path}
- Module: {module}
- Priority / State: {priority} / {state}
- ADRs referenced: {list}

## Coverage Matrix

| Layer | Status | Detail |
|-------|--------|--------|
| Feature (02_features) | ✅ | {file} |
| UISpec (05_ui) | ✅/❌/N/A | Screens: {list} |
| Prototype (/prototype) | ✅/⚠️/❌/N/A | Drift: {count} |
| Specs (04_specs) | ✅/❌/N/A | Actions: {list} |
| ADR alignment | ✅/⚠️/❌ | |

## Issues
- [{severity}] {description} — {file}:{line} | Fix: `/{skill}`

## OK
```

### Batch mode (module)

Reviews ALL features of a module in parallel.

1. Read the module's `_index.md` and extract all feature/use-case IDs from the
   use-case index.
2. Present the list to the user and **ask for confirmation** before proceeding.
3. On confirmation, **launch one Agent per feature in parallel** — each runs the
   single-feature review.
4. Collect results.
5. **Synthesize** a consolidated report: aggregated coverage matrix, issues grouped
   by severity, and patterns (e.g. "5 features missing UISpec coverage").
6. If issues are found, present a **correction plan**: ordered actions grouped by
   the skill to invoke.

**Output format (batch):**

```markdown
# Feature Review: {module} (batch) | {date}

## Scope
{N} features reviewed: {list}

## Aggregated Coverage Matrix
| Feature | 02_features | UISpec | Prototype | Specs | ADR |
|---------|-------------|--------|-----------|-------|-----|
| PRV-01  | ✅          | ✅     | ⚠️ (3)    | ❌    | ✅  |
| ...     |             |        |           |       |     |

## Summary
- Full coverage: {N} · Gaps: {N} · Drift items pending: {count}

## Issues by Severity
### Critical / Important / Minor

## Correction Plan
1. `/inspire_ui` — Add screens for: {list}
2. `/inspire_prototype` — Adopt components for: {list}
```

## Subcommand: scan

The feature-level entry point for SDD-layer work. Same three phases as
[`/inspire_module scan`](../inspire-module/SKILL.md#subcommand-scan), scoped to one
feature or one module's features:

1. **Environment setup** — confirm a clean worktree on the right branch, or offer
   to bootstrap one (direct `git worktree add`; do NOT defer to a third-party
   worktree skill — the `inspire-*` family must stay portable).
2. **Candidate surfacing + narrowing** — read the feature file, infer the actions
   that would realize it (most features map to 1–3), apply plural→singular
   canonicalization on action ids silently, check whether each already exists at
   `.inspire_kb/04_specs/{module}/{entity}/{action}.md`, and dialogue with the
   operator to pick a set. One focused question at a time; follow the
   conversational conventions of [`/inspire_object`](../inspire-object/SKILL.md).
3. **Chained authoring** (only on an explicit "start" signal) — create one
   `TaskCreate` per chosen action, mark the first `in_progress`, and invoke
   `/inspire_object define {id}` via the Skill tool; `inspire-object` runs its
   socratic interview and may co-evolve the action + entity documents in one flow.

Scan is read-only with respect to `.inspire_kb/04_specs/`; authoring lives in
`/inspire_object`. Pure exploration leaves no tasks created. **Batch mode**
(`scan {module}`) expands this over every feature in the module's `_index.md`.

### Phase 4 — Audit report

After the dialogue, scan surfaces per-feature audit findings: features with no
realizing action, partial realization, and lifecycle mismatch (feature marked
implemented but realizing actions still `lifecycle: draft`). Render via
[`_references/findings-format.md`](../_references/findings-format.md).

## Subcommand: create

Create a new feature/use-case file in a module. **Required arg:**
`{module}/{feature-id}` (e.g. `ai-agents/AIA-08`).

1. **Verify** the module exists (`.inspire_kb/02_features/{module}/`).
2. **Ask** the user: name, description (2–5 sentences), actor/personas,
   dependencies (other feature IDs), priority (Core / Important / Nice-to-have),
   state (🟡 Planned default), ADRs to reference.
3. **Create the use-case file** `.inspire_kb/02_features/{module}/{feature-id}.md`
   from the template below.
4. **Update the module `_index.md`** — add the row to the use-case index and fix
   the summary totals.
5. **Report next steps:**
   - If UI-facing → `/inspire_ui` to add a screen spec.
   - If it describes a behavior/endpoint → `/inspire_object define
     {module}::{entity}::{verb}` to author the action descriptor.
   - Prototype → `/inspire_prototype` when ready.

**Feature ID convention:** the module's prefix + the next available number (scan
existing IDs), per the convention recorded in the module `_index.md` /
`00_bootstrap`.

## Subcommand: update

Modify an existing feature. Use for: changing the description, adding/removing
dependencies, promoting priority, changing state
(`🟡 Planned` → `🔵 In progress` → `🟢 Implemented`), or renaming.

1. Read the current use-case file.
2. Present a diff proposal to the user.
3. On approval, apply it.
4. If renamed: update the module `_index.md`, and grep `.inspire_kb/` (and any
   project code) for references to the old ID and offer fixes.
5. Run `review {feature-id}` to verify no drift.

## Subcommand: delete

Remove a feature and clean up all references.

1. **Confirm** with the user: list every file touching this feature.
2. Delete the use-case file
   (`.inspire_kb/02_features/{module}/{feature-id}.md`).
3. Remove its row from the module `_index.md` and fix the summary totals.
4. **UISpec:** remove the feature ID from any screen's `**Features:**` line; if a
   screen's only feature was this one, flag it for removal (that's `/inspire_ui`'s
   job) and update the UISpec `_index.md` coverage table.
5. **Prototype:** remove references in `/prototype`; prune stale learnings in
   `.inspire_kb/03_prototypes/`.
6. **ADRs:** grep `.inspire_kb/01_adr/`; if an ADR mentions this feature, flag it —
   may need an ADR update.

## Use case template

Use this template at `.inspire_kb/02_features/{module}/{feature-id}.md`:

```markdown
# {FEATURE-ID}: {Feature Name}

> Source: [[{module}/_index]]

## Actor
{Primary persona}

## Preconditions
{What must be true before this flow starts}

## Main flow
1. {Step 1}
2. {Step 2}

## Alternative flows
### AF-1: {Description}

## Error flows
### EF-1: {Description}

## Postconditions
{What is true after successful completion}

## Acceptance criteria
- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}
```

## Rules

1. **The use-case file is the source of truth.** Everything else (UISpec,
   prototype, specs) references or realizes it.
2. **One file per use case.** The filename matches the feature ID.
3. **Use cases are functional, not technical.** They describe WHAT from the user's
   perspective, not HOW — no SQL, no API paths, no component names.
4. **`review` is read-only.** `create` / `update` / `delete` require user approval
   of the plan before writing.
5. **Propagation is mandatory.** Deleting or renaming a feature without cleaning
   references is drift.
6. **N/A is valid.** Not every feature needs every layer — infrastructure features
   may have no UI.
7. **Drift is informational.** `## Prototipo actual` drift items don't block
   reviews unless they contradict an accepted ADR.
8. **Batch synthesis.** In batch review, identify patterns and produce a
   prioritized correction plan grouped by fix skill.
9. **Consult the task tracker** (`/inspire_workspace task list`, or
   `node .inspire_kb/06_tracker/serve.mjs`) for tracked drift; don't re-surface it
   as new.
