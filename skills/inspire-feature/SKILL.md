---
name: inspire-feature
description: "Lifecycle of a feature: create / review / update / delete in the PDD submodule + optional use case + propagate across layers. Use when adding, auditing, or removing features."
---

# /inspire_feature — Feature-level Operations

## Scope

This skill owns **feature-scoped** operations. A "feature" is a `### {ID} · {Name}` block inside a PDD submodule file (`spec/pdd/core/{module}/{submodule}.md`).

## Invocation

- `/inspire_feature review {feature-id}` — single feature, all layers
- `/inspire_feature review {module}` — batch mode, all features of a module (parallel agents)
- `/inspire_feature create {module}/{feature-id}` — new feature + optional use case
- `/inspire_feature update {feature-id}` — modify description, dependencies, priority
- `/inspire_feature delete {feature-id}` — remove + orphan checks across layers
- `/inspire_feature scan {feature-id}` — SDD layer alignment for one feature (fast)
- `/inspire_feature scan {module}` — batch SDD layer alignment for all features of a module

## Subcommand: review

### Single feature mode

Reviews one feature across all layers. Runs inline (no agents).

**Steps:**

1. **Locate the feature definition**
   - Find the PDD submodule file containing the feature ID in `spec/pdd/core/{module}/`
   - Read: description, personas, dependencies, priority, state, ADRs referenced
   - Identify the module from the folder path

2. **UISpec coverage**
   - Detect structure: new folder (`spec/specs/ui/openbims-console/{module}/*.md`) or legacy monolith
   - **New:** search each screen file's `**Features:**` line for this feature ID; cross-reference with the UISpec `_index.md` Feature coverage table
   - **Legacy:** search "Features cubiertas" sections
   - Flag if NO screen covers this feature (critical if UI-facing)
   - Note "No UI expected" for backend/infrastructure features

3. **Prototype coverage**
   - For each covering screen, read its `## Prototipo actual` section
   - Verify the named `.jsx` file exists and is routed in `App.jsx`
   - Note drift items (pending component adoption, hardcoded data, ADR gaps)
   - Flag orphan `.jsx` components that claim to implement this feature but aren't referenced in any screen

4. **Mock-data coverage**
   - Identify entities/tables referenced in the feature description
   - Verify tables exist in `mock-data/schema/`
   - Verify JSONL data files exist in `mock-data/tables/`
   - Verify FKs resolve
   - Flag missing tables or empty JSONL

5. **Manual coverage**
   - Verify the module's manual page mentions or explains this feature
   - Flag if user-facing but not documented

6. **API spec coverage** (if applicable)
   - If the feature describes an API endpoint, verify it exists in `spec/specs/api/`
   - Flag as `minor` if missing (API spec layer still being populated)

7. **Realizing actions (SDD layer)**
   - Find action descriptors whose `## Why` body wikilinks back to this feature (or to the PDD section the feature lives in). Search `spec/sdd/**/*.md` for `[[{feature-id}]]` or `[[pdd-{module}-...]]` near the feature.
   - Flag if zero realizing actions exist (the feature is described in PDD but never realized as an action).
   - For realizing actions, report `id`, `lifecycle`, and a one-line summary of `## Why`.

8. **Use case coverage**
   - If a use case exists at `spec/specs/usecases/{module}/{feature-id}.md`, verify it aligns with the current PDD definition
   - If no use case and the feature has complex flows: note as potential candidate

9. **ADR alignment**
   - If the feature references an ADR (`[[adr-xxx]]`), verify the ADR exists and is `accepted`
   - If prototype "Drift a resolver" items reference unimplemented ADR requirements, surface them

**Output format (single):**

```markdown
# Feature Review: {feature-id} · {feature-name} | {date}

## Feature Definition
- File: {path}
- Module: {module}
- Priority: {priority}
- State: {state}
- ADRs referenced: {list}

## Coverage Matrix

| Layer | Status | Detail |
|-------|--------|--------|
| PDD | ✅ | Defined in {file}:{line} |
| UISpec | ✅/❌/N/A | Screens: {list} (new|legacy) |
| Prototype | ✅/⚠️/❌/N/A | Components: {list} · Drift: {count} |
| Mock Data | ✅/❌ | Tables: {list} |
| Manual | ✅/❌ | Section in {file} |
| API Spec | ✅/❌/N/A | |
| Use case | ✅/❌ | {path} |
| ADR alignment | ✅/⚠️/❌ | |

## Issues
- [{severity}] {description} — {file}:{line} | Fix: `/{skill}`

## OK
```

### Batch mode (module)

Reviews ALL features of a module in parallel.

**Steps:**

1. Read the module's `_index.md` (`spec/pdd/core/{module}/_index.md`) and extract ALL feature IDs from the Índice de Features table
2. Present the feature list to the user and **ask for confirmation** before proceeding
3. On confirmation, **launch one Agent per feature in parallel** — each runs the single-feature review
4. Collect all agent results
5. **Synthesize** a consolidated report: aggregated coverage matrix, grouped issues by severity, patterns (e.g., "5 features missing manual coverage", "all SKL-* features lack mock-data")
6. If issues are found, **present a correction plan**: ordered list of actions grouped by skill to invoke, with estimated scope

**Output format (batch):**

```markdown
# Feature Review: {module} (batch) | {date}

## Scope
{N} features reviewed: {list}
UISpec structure: new | legacy | migrating

## Aggregated Coverage Matrix
| Feature | PDD | UISpec | Prototype | Mock | Manual | API | UseCase | ADR |
|---------|-----|--------|-----------|------|--------|-----|---------|-----|
| PRV-01  | ✅  | ✅     | ⚠️ (3)    | ✅   | ✅     | N/A | ❌      | ✅  |
| ...     |     |        |           |      |        |     |         |     |

## Summary
- Full coverage: {N}
- Gaps: {N}
- Drift items pending: {count}

## Issues by Severity
### Critical / Important / Minor

## Patterns
- {N} features missing {layer} coverage
- {systemic issue}

## Correction Plan
1. `/inspire_ui` — Add screens for: {list}
2. `/inspire_prototype` — Adopt components for: {list}
```

## Subcommand: scan

The feature-level entry point for SDD-layer work. Three phases, same shape as [`/inspire_module scan`](../inspire-module/SKILL.md#subcommand-scan), but scoped to one feature or one module's features:

1. **Environment setup** — confirm clean worktree on the right branch, or offer to bootstrap.
2. **Candidate surfacing + narrowing** — read the feature's PDD section, list candidate actions to realize, dialogue with the operator to pick a set.
3. **Chained authoring** — for the chosen set, create TaskCreate items and chain serially to `/inspire_object define`. Authoring proceeds via the **socratic interview** pattern owned by that skill — section-by-section probing of design implications, not template fill-in.

Scan is read-only with respect to `spec/sdd/`. Authoring lives in `/inspire_object`.

### Phase 1 — Environment setup

Same as [`/inspire_module scan` Phase 1](../inspire-module/SKILL.md#phase-1--environment-setup):

- Check current git worktree, branch (expecting `feat/sdd-{module}` or similar), clean working tree.
- If any check fails, offer the operator a conversational choice: bootstrap a fresh worktree (`.claude/worktrees/sdd-{module}/`, branch `feat/sdd-{module}` off `origin/main`), continue in current worktree if branch is appropriate, or abort.
- On bootstrap confirmation, run directly:
  ```bash
  git worktree add .claude/worktrees/sdd-{module} -b feat/sdd-{module} origin/main
  ```
  Direct shell call via Bash. Do NOT defer to `superpowers:using-git-worktrees`. Portability over orthodoxy.

### Phase 2 — Candidate surfacing + narrowing

Read the relevant PDD content based on mode:

**Single-feature mode** (`/inspire_feature scan {feature-id}`):
- Locate the feature in `spec/pdd/core/{module}/{submodule}.md` — find its `### {ID} · {Name}` block plus description, dependencies, ADRs referenced.
- Infer candidate actions: what verbs would realize this feature? Most features map to 1–3 actions. Surface the inferred ids with PDD back-source wikilinks.
- Apply plural→singular canonicalization on any PDD action ids surfaced (e.g. `platform::actions::resolve` → `platform::action::resolve` for the SDD id). Silent normalization; do NOT surface as a "naming reconciliation" question.
- Check whether each candidate already exists at `spec/sdd/{module}/{entity}/{action}.md`.

**Batch mode** (`/inspire_feature scan {module}`):
- Same as single-feature, expanded to every feature in the module's `_index.md` Índice de Features.
- For each feature, run the single-feature analysis above; aggregate candidates across the module.

Then dialogue with the operator. For single-feature mode:

```
"Feature {feature-id} ({feature-name}) likely realizes as N actions:
 - {module}::{entity}::{action-1}  (read/write {entity})
 - {module}::{entity}::{action-2}  (read/write {entity})
 (M of these already exist as descriptors.)

 Want to talk through the inferred shape, or pick a set to author?"
```

Narrow the set conversationally. Follow the conversational conventions of [`/inspire_object`'s SKILL.md](../inspire-object/SKILL.md#conversational-ownership): one focused question at a time, no decision-tree options, show-then-approve.

### Phase 3 — Chained authoring (when the operator signals start)

Identical to [`/inspire_module scan` Phase 3](../inspire-module/SKILL.md#phase-3--chained-authoring-when-the-operator-signals-start):

1. On explicit "let's start" signal, create one `TaskCreate` per chosen action (canonicalized id).
2. Mark first task `in_progress`; invoke `/inspire_object define {id}` via Skill tool.
3. After completion, ask operator whether to continue with the next task. On yes → serial chain. On no → pause; tasks remain in queue.

**Co-evolution mid-interview.** The socratic interview may pivot from action to entity authoring inside a single `define` invocation — when discussion surfaces a new field, `/inspire_object` captures it on both the action descriptor and the entity document in the same flow (see that skill's "Conversation capture" section). The operator does not switch contexts manually; the object skill handles the bipartite walk. Scan's job ends at the handoff.

Pure-exploration exits (operator just wants to see what's there) leave no tasks created unless the operator explicitly asks for a queue. Scan as exploration is preserved.

### Phase 4 — Audit report (existing behavior)

In addition to Phases 1–3, scan surfaces per-feature audit findings (existing behavior from the prior implementation):

- Features with no realizing action
- Partial realization (e.g. only one of multiple inferred actions exists)
- Lifecycle mismatch — feature marked `🟢 Implemented` but realizing actions still at `lifecycle: draft`

Render via [`_references/findings-format.md`](../_references/findings-format.md). Audit findings come at the end of the report, after the candidate-narrowing dialogue concludes.

## Subcommand: create

Create a new feature in a module's PDD submodule + optional use case.

**Required args:** `{module}/{feature-id}` (e.g., `ai-agents/AIA-AGT-08`)

**Steps:**

1. **Verify** the module exists (`spec/pdd/core/{module}/` or satellite)
2. **Ask** the user:
   - Which submodule does it belong to? (list existing submodules)
   - Name, description (2-5 sentences)
   - Personas (from the module's persona list)
   - Dependencies (other feature IDs)
   - Priority (Core / Important / Nice-to-have)
   - State (🟡 Planned default)
   - ADRs to reference?
   - Does this feature need a use case? (typically yes for complex flows)
3. **Insert the feature block** in the appropriate submodule file at the right location (by category)
4. **Update the Índice de Features** table in the module's `_index.md`
5. **Update the Resumen** table totals
6. **Create use case** (if requested): `spec/specs/usecases/{module}/{feature-id}.md` using the template
7. **Report next steps:**
   - If UI-facing: invoke `/inspire_ui` to add a screen spec
   - If API endpoint: invoke `/inspire_object define {module}::{entity}::{verb}` to author the action descriptor
   - Prototype: invoke `/inspire_prototype` when ready

**Feature ID convention:** `{MODULE}-{SUBSYSTEM}-{NN}` where `{NN}` is the next available number in that subsystem (scan existing IDs to find the next).

## Subcommand: update

Modify an existing feature definition.

**Use for:**
- Changing description
- Adding/removing dependencies
- Promoting priority
- Changing state (`🟡 Planned` → `🔵 In progress` → `🟢 Implemented`)
- Renaming (requires propagation — confirm)

**Steps:**

1. Read current feature block
2. Present diff proposal to user
3. On approval, apply to PDD submodule
4. If renamed:
   - Update `_index.md` Índice de Features
   - Grep `spec/` for references to old ID, offer fixes
   - Grep `mock-data/` for references (e.g., `source: 'AIA-AGT-01'` in audit events)
   - Grep `code/` for hardcoded references
5. Run `review {feature-id}` to verify no drift

## Subcommand: delete

Remove a feature and clean up all references.

**Steps:**

1. **Confirm** with user: list every file touching this feature
2. Delete the `### {ID} · {Name}` block from the submodule file
3. Remove row from the module's `_index.md` Índice de Features table
4. Update Resumen totals
5. Delete use case file if present (`spec/specs/usecases/{module}/{feature-id}.md`)
6. For UISpec:
   - Remove feature ID from any screen's `**Features:**` line
   - If a screen's only feature was this one → flag for removal (don't auto-delete; that's `/inspire_ui`'s job)
   - Update UISpec `_index.md` Feature coverage table
7. For prototype: grep `code/` for hardcoded feature ID references and remove
8. For manual: find the feature's manual entry (may be within a module section) and propose removal
9. Grep `spec/adrs/` for references; if an ADR mentions this feature, flag — may need ADR update

## Use case template

When creating a use case, use this template at `spec/specs/usecases/{module}/{feature-id}.md`:

```markdown
# {FEATURE-ID}: {Feature Name}

> Source: [[{module}/_index]] or [[{module}/{submodule}]]

## Actor
{Primary persona from the PDD feature}

## Preconditions
{What must be true before this flow starts}

## Main flow
1. {Step 1}
2. {Step 2}
3. ...

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

1. **PDD is the source of truth.** The feature definition lives in the submodule file; everything else references or documents it.
2. **One file per use case.** Filename matches the feature ID.
3. **Use cases are functional, not technical.** They describe WHAT from the user's perspective, not HOW. No SQL, no API paths, no component names.
4. **`review` is read-only.** `create`, `update`, `delete` require user approval of the plan before writing.
5. **Propagation is mandatory.** Delete/rename a feature without cleaning references = drift. Always propagate.
6. **N/A is valid.** Not every feature needs every layer. Infrastructure features may have no UI. Backend features may have no manual entry yet.
7. **Drift is informational.** `## Prototipo actual` "Drift a resolver" items don't block reviews unless they contradict an accepted ADR.
8. **Batch synthesis.** In batch review, identify patterns and produce a prioritized correction plan grouped by fix skill.
9. **Consult the task tracker** (`/inspire_workspace task list` or `node tracker/serve.mjs`) for tracked drift; don't re-surface it as new.
10. **No audit/log features outside the Audit module** (per [[adr-audit-01-centralized-logging]]). If a proposed feature is about logging actions, viewing activity logs, hash-chained events, or retention of auditable records, it belongs to Audit (LOG-01..10). In `create`, reject such features when the target module is not `audit`, and redirect the author to either (a) add a feature to Audit if novel, or (b) rely on existing LOG-01..10 with the appropriate `category`/`module` filter. In `review`, flag any `{MODULE}-LOG-*` / `{MODULE}-ADT-*` / "Audit Trail" features in non-audit modules as a violation. Allowed exception: a module-specific screen that merely **links** to `/audit/logs?module={module}` (no store, no separate feature).

## Checklist for new features

Before writing a feature to a non-audit module PDD, ask:

- Is this feature about recording, storing, retrieving, filtering or displaying audit events? → Redirect to Audit.
- Does it propose a `{module}_audit_events` table or equivalent? → Reject, use `@openbims/audit` + central store.
- Does it propose a dedicated "Audit Trail" / "Activity Log" screen in sidebar? → Reject, link to `/audit/logs?module=...` instead.

If the feature passes the checklist, proceed.
