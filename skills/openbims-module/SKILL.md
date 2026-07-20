---
name: openbims-module
description: "Lifecycle of a module: create / review / update / delete its PDD and propagate changes across all layers. Use when scaffolding a new module, auditing an existing one before a PR, or removing a module."
---

# /openbims_module — Module-level Operations

## Scope

This skill owns **module-scoped** operations. A "module" is a folder in `spec/pdd/core/{module}/` (core module) or a file/folder in `spec/pdd/satellite/` (satellite module).

## Invocation

- `/openbims_module review {module}` — full consistency review before PR
- `/openbims_module create {module}` — scaffold a new module across all layers
- `/openbims_module update {module}` — add/remove features, restructure submodules, propagate across layers
- `/openbims_module delete {module}` — remove the module and clean up every cross-reference

## Subcommand: review

Runs all consistency checks for the module. This is the **required gate before any PR** that modifies files in `spec/pdd/core/{module}/`.

### Steps

#### 1. PDD structure validation

**Index file (`_index.md`):**
- Exists in the module folder
- Is a **pure index**: intro, architecture, module relationships, Subsistemas table, Índice de Features table, Resumen. **NO feature definition blocks** (`### {ID} · {Name}` + description + metadata).
- Has a **Subsistemas** table linking to each submodule file via `[[wikilinks]]`
- Has an **Índice de Features** table listing ALL feature IDs with wikilinks to their submodule
- Has a **Resumen** table with correct totals (Total = sum of subsystems; Core + Important = Total)

**Submodule files:**
- Every `.md` file in the module folder (except `_index.md`) is referenced in the Subsistemas table
- Every submodule file has a back-link `[[_index|ModuleName]]` in its intro
- No orphan submodule files (exist on disk but not in the index)
- No phantom submodule references (in the index but file doesn't exist)

**Feature completeness:**
- Read ALL submodule files completely and extract every `### {ID} · {Name}` block
- Compare extracted features against the Índice de Features table in `_index.md`
- Flag: features defined in submodules but missing from the index
- Flag: features listed in the index but not defined in any submodule
- Flag: feature count in Resumen doesn't match actual count

#### 2. UISpec structure validation

Detect which UISpec structure the module uses:

- **New structure (preferred):** folder `spec/specs/ui/openbims-console/{module}/` with `_index.md` + one file per screen
- **Legacy monolith:** single file `spec/specs/ui/openbims-console/UISpec_{Module}.md`
- **Both exist simultaneously:** error — migration incomplete; legacy should be deleted once new is complete

**For new structure:**
- Module `_index.md` exists and contains: sidebar navigation, route map table, feature coverage table
- Every screen file in the folder is referenced in the route map
- Every referenced screen file exists on disk
- Every screen file has header with `**Features:**`, `**Pattern:**`, `**PDD:**`
- Every `**Pattern:**` resolves to an existing file in `spec/specs/ui/openbims-console/patterns/` (or `bespoke` with justification)
- Every `[[../components/X]]` wikilink resolves
- No screen redescribes design tokens (those live in `design-system.md`)
- No screen contains ASCII layout unless marked `bespoke`
- No inline mock data (must reference tables)
- Each screen is under ~250 lines

**For legacy monolith:**
- Flag as `important`: module should be migrated
- Apply legacy checks (feature IDs, no historical language, no contradictions)

#### 3. Quality checks

- No historical language anywhere: `"anteriormente"`, `"antes de"`, `"reemplaza a"`, `"eliminado"`, `"absorbido"`, `"migrado de"`, `"ex-"`, `"absorbe"`, strikethrough `~~text~~`
- No embedded ADR content (>10 lines rationale without ADR link)
- Feature IDs use correct prefix for the module (check CLAUDE.md module table)
- No duplicate feature IDs across all submodule files
- All `[[wikilinks]]` resolve to existing files (including cross-folder: patterns/, components/, adrs/, design-system.md)

#### 4. Cross-layer coverage

**PDD ↔ UISpec:**
- Every PDD feature with UI implications has a screen
- Every screen's `**Features:**` line references features that exist in the PDD
- The UISpec `_index.md` feature coverage table aligns with actual screen declarations

**PDD ↔ Prototype:**
- Every screen's `## Prototipo actual` names a real `.jsx` file (or declares "not yet implemented")
- Every `.jsx` page in the module folder is referenced by at least one screen
- Routes declared in screen headers match `App.jsx`

**PDD ↔ Mock Data:**
- Entities referenced in PDD have tables in `mock-data/schema/`
- Tables have JSONL data files
- No orphan JSONL files for this module

**PDD ↔ Manual:**
- Module has a page in `manual/modules/{module}.html`
- Manual page reflects current PDD (no stale content for removed features)

**Cross-cutting: centralized logging** (per [[adr-audit-01-centralized-logging]]):
- Flag if the module defines any table like `{module}_audit_events`, `{module}_logs`, `{module}_activity_log`, or any other local store of audit events.
- Flag if the module defines a screen dedicated to viewing logs/audit events (route like `/{module}/audit`, `/{module}/logs`, or sidebar entry "Audit Trail").
- Flag if the module PDD describes emitting audit events "via Channels" or "via Event Bus" — the canonical wording is "via `@openbims/audit`".
- Exception: the `audit` module itself owns `audit_events`, `LOG-*`, and related surfaces.

**Module landing pages** (per [[adr-ux-01-module-landing-pages]]):
- Flag any PDD feature framed as "module dashboard" / "module overview" / "module home" whose sole purpose is being the `/{module}` landing.
- Flag UISpec `dashboard.md` routed as `/{module}` (vs `/{module}/{resource}/:id/analytics`).
- Flag prototype `{Module}Dashboard.jsx` rendered at `/{module}` in `App.jsx`.
- Flag sidebar entry labeled "Dashboard"/"Overview" pointing to `/{module}` root.
- Recommend: `<Route path="/{module}" element={<Navigate to="/{module}/{primary-list}" replace />} />`.

**Module-level settings** (per [[adr-ux-02-settings-location]]):
- Flag UISpec `settings.md` routed as `/{module}/settings` in non-Platform modules.
- Flag prototype `{Module}Settings.jsx` as a dedicated page routed at `/{module}/settings`.
- Flag sidebar entry labeled "Settings" under a functional module.
- For each settings section in such a page, identify its natural home: a tab in the primitive's screen, a subsystem's screen, or Platform for cross-module concerns.
- Exception: the Platform module owns the global Settings role (its sidebar label is "Settings" at top level).

#### 5. SDD layer coverage

Run `.claude/bin/review.sh spec/sdd/{module}/` and incorporate findings. The rule set covers:
- `acyclic-deps` — no cycles or self-loops in the `requires` graph
- `stable-blockers` — stable actions don't require non-stable targets
- `touched-entity-lifecycle` — stable actions touch only entities ≥ accepted
- `entity-coherence` — per-field type-conflict, unsourced, and orphan-write findings

Render findings via the shared format at [`.claude/skills/_references/findings-format.md`](../_references/findings-format.md). Do not inline a re-spec.

Additionally for SDD-layer coverage:
- Every PDD feature that describes a behavior should have at least one realizing action descriptor in `spec/sdd/{module}/`. Flag features with no realizing action as `important`.
- Every action descriptor's `## Why` should back-source to a PDD section via `[[wikilink]]`. Flag orphan actions (no PDD back-source) as `important`.

#### 6. Drift consolidation

For new-structure UISpecs, screens contain `## Prototipo actual` sections with drift items. Consolidate:

- Count total drift items
- Group by type: component adoption, data wiring, gap (no .jsx yet), ADR alignment
- Report as summary
- Priority: ADR alignment > data wiring > component adoption > cosmetic

#### 7. Overengineering detection

- UI described in screens not in the `components/` catalog and used in <2 screens
- Patterns not in the catalog and not justified as bespoke
- `.jsx` pages with no screen spec and no PDD feature justification
- Mock-data tables not referenced by any PDD feature

### Output format

```markdown
# Module Review: {module} | {date}

## Summary
- UISpec structure: new | legacy | migrating
- Features in PDD: {count}
- Screen files: {count}
- Drift items pending: {count}
- Issues: {critical} critical, {important} important, {minor} minor

## PDD Structure
- Submodule files: {list}
- Index accuracy: {ok | N mismatches}

## UISpec Structure
- Path: {folder or monolith file}
- Pattern usage: {list} | {bespoke count}
- Component usage: {list}

## Critical
- [{module}] {description} — {file}:{line} | Fix: `/{skill}`

## Important / Minor
- ...

## Drift Summary
- Component adoption pending: ...
- Data wiring pending: ...
- Gap (new pages): ...
- ADR alignment pending: ...

## OK
- ...
```

## Subcommand: create

Scaffold a new module across all layers. User provides module name, prefix (e.g. `MYM`), and description.

### Steps

1. **Create PDD folder:** `spec/pdd/core/{module}/`
   - `_index.md` with intro skeleton + empty Subsistemas and Índice de Features tables
   - Initial submodule files if the user describes >1 subsystem

2. **Register in top-level index:** add entry in `spec/pdd/_index.md` for this module

3. **Create UISpec folder:** `spec/specs/ui/openbims-console/{module}/`
   - `_index.md` skeleton with empty route map and feature coverage tables
   - No screens yet — user adds via `/openbims_feature create` or `/openbims_ui create`

4. **Create mock-data schema file:** `mock-data/schema/{NN}_{module}.sql`
   - Empty DDL shell with module comment

5. **Create manual stub:** `manual/modules/{module}.html`
   - Module description placeholder

6. **Add route prefix in prototype (optional, when pages exist):** point user to `/openbims_prototype` to add the module folder and routes

7. **Update CLAUDE.md** module table with the new module

Report what was created and next steps (typically: invoke `/openbims_feature create` for the first features).

## Subcommand: update

Modify an existing module. Use for:
- Adding/removing a subsystem submodule file
- Renaming a feature ID globally (with FK updates across mock-data)
- Moving features between submodules
- Restructuring after a new ADR

The update operates transactionally: propose the changes first, get user approval, then apply across layers.

Steps:
1. Read current state (PDD + UISpec + mock-data + manual)
2. Present the diff proposal to the user
3. On approval, apply edits
4. Run `review {module}` to verify no drift introduced

## Subcommand: scan

The entry point for SDD-layer work on a module. Three phases:

1. **Environment setup** — confirm the operator is in a clean worktree on the right branch, or offer to bootstrap one.
2. **Candidate surfacing + narrowing** — read the PDD, list PDD features without realizing SDD action descriptors, dialogue with the operator to pick a set.
3. **Chained authoring** — for the chosen set, create TaskCreate items and chain serially to `/openbims_object define`. Authoring proceeds via the **socratic interview** pattern owned by that skill, which probes design implications section by section rather than fill-in-template.

Scan is read-only with respect to `spec/sdd/`; it never authors descriptors itself. Authoring lives in `/openbims_object`.

### Phase 1 — Environment setup

When invoked, check:

- Are we currently in a git worktree?
- Is the branch one of the operator's per-module SDD branches (e.g. `feat/sdd-{module}`)?
- Is the working tree clean?

If all three are yes, proceed to Phase 2.

If any is no, surface the gap to the operator and offer options conversationally:

- **Bootstrap a fresh worktree** for this module at `.claude/worktrees/sdd-{module}/`, branch `feat/sdd-{module}` off `origin/main` (or whatever the active SDD-base branch is).
- **Continue in the current worktree** — only valid if the current branch makes sense for this module.
- **Abort** — operator wants to set up environment themselves.

When the operator confirms bootstrap, run directly:

```bash
git worktree add .claude/worktrees/sdd-{module} -b feat/sdd-{module} origin/main
```

Direct shell call via the Bash tool. **Do NOT defer to `superpowers:using-git-worktrees`** or any other skill. Operators may not have superpowers installed; the openbims-* skill family must stay portable.

### Phase 2 — Candidate surfacing + narrowing

Read the module's PDD:

- `spec/pdd/core/{module}/_index.md` — extract the Action Catalog table rows
- `spec/pdd/core/{module}/{submodule}.md` for each submodule — extract feature descriptions and any action declarations they carry

For each PDD action declaration like `platform::actions::resolve`:

- **Canonicalize plural → singular**. `platform::actions::resolve` becomes the SDD id `platform::action::resolve`. This is a known convention shift between layers — apply it silently. Do NOT surface it as a "naming reconciliation" question or as a decision tree. Same intention, just a layer convention.
- Check whether `spec/sdd/{module}/{entity}/{action}.md` exists.
- If no — it's a candidate.

Surface candidates and dialogue:

```
"I see N PDD-declared actions for {module} that aren't yet authored as SDD descriptors:
 - platform::action::resolve  (from action-catalog subsystem, [[PDD-platform-...]])
 - platform::action::list
 - platform::action::register
 (plus M existing descriptors at spec/sdd/{module}/)

 Want to look at any of these in more depth, or pick a set to start with?"
```

Then converse — narrow the set based on what the operator wants to prioritize. **Do not enumerate decision-tree options**; let the dialogue decide. Follow the conversational conventions of [`/openbims_object`'s SKILL.md](../openbims-object/SKILL.md#conversational-ownership) (this skill borrows them for its dialogue phase): one focused question at a time, show-then-approve.

### Phase 3 — Chained authoring (when the operator signals start)

When the operator's narrowing has produced a set of ≥1 actions to author AND they have **explicitly signaled "let's start"** (not just "these are interesting" or "let me think"):

1. Create one `TaskCreate` per chosen action with the canonicalized SDD id in the description.
2. Mark the first task `in_progress`.
3. Invoke `/openbims_object define {first-id}` via the Skill tool (programmatic chain). `openbims-object` takes over and runs its socratic interview from here.
4. When `openbims-object`'s subcommand completes, return to this skill's frame. Ask the operator if they want to continue with the next task. On yes → mark next `in_progress` → chain. On no → pause cleanly; tasks remain in the list for later.

**Co-evolution mid-interview.** The socratic interview may pivot from action authoring to entity authoring inside a single `define` invocation — when an action's field-touch discussion surfaces a new field that the entity document does not yet declare, `/openbims_object` captures the change on both files in the same flow (see its "Conversation capture" section). The operator does not need to switch contexts manually; the object skill handles the bipartite walk. Scan's job ends at the handoff.

If the operator's dialogue produces no chosen set (pure exploration), or they explicitly say "just review the report," scan ends after Phase 2. No tasks are created (or tasks for all candidates if the operator wants a queue for later, at their explicit request). **The operator's right to use scan as exploration is preserved** — scan is NOT "first-action-found-triggers-define."

### Phase 4 — Audit report (existing behavior, runs after Phases 1–3)

In addition to the entry-point phases, scan still produces the audit signals from the existing SDD-layer review (per the prior implementation):

- Features without realizing actions
- Orphan actions (no PDD back-source)
- Coherence conflicts (via `entity-coherence`)

These come at the **end** of the report, after the candidate-narrowing dialogue concludes. They serve as the impetus for further `scan` invocations or follow-up `/openbims_object review` runs. Render via [`_references/findings-format.md`](../_references/findings-format.md).

`scan {module}` batches over a single module; `scan` without args batches over every core module in `spec/pdd/core/`.

## Subcommand: delete

Remove a module across all layers. Use with caution.

### Steps

1. **Confirm** with user: list all files and features about to be deleted
2. **PDD:** delete `spec/pdd/core/{module}/` folder
3. **UISpec:** delete `spec/specs/ui/openbims-console/{module}/` folder OR legacy `UISpec_{Module}.md`
4. **Mock data:**
   - Delete or rename `mock-data/schema/{NN}_{module}.sql`
   - Delete JSONL files for this module's tables
   - Remove entries from `code/openbims-console/src/db/client.js` `discoverTables` array
5. **Prototype:** delete `code/openbims-console/src/modules/{module}/` folder. Remove imports and routes from `App.jsx`. Remove entries from `Sidebar.jsx`.
6. **Manual:** delete `manual/modules/{module}.html`. Remove from `nav.js` `NAV_STRUCTURE`.
7. **Cross-references:**
   - Grep the whole `spec/` for `[[{module}]]` or feature-ID references of that module — flag and offer fixes
   - Check ADRs under `spec/adrs/` for references to this module
   - Check other modules' `_index.md` "Relación con otros módulos" sections
8. **Top-level index:** remove from `spec/pdd/_index.md`
9. **CLAUDE.md:** remove from the module table

## Rules

1. **`review` is read-only.** It reports, suggests fixes, and recommends other skills; it never edits files.
2. **`create` requires user input** for module name, prefix, initial subsystem structure.
3. **`update` and `delete` require an explicit plan** presented to the user before any edit.
4. **Propagation is mandatory.** A module operation that only touches PDD and leaves UISpec/mock/prototype inconsistent is a bug — use the cross-layer propagation logic.
5. **Pending drift is acceptable.** Drift items listed in `## Prototipo actual` sections of screens are informational; don't block PRs unless they contradict an accepted ADR.
6. **Consult the task tracker** at the start of each invocation (`/openbims_workspace task list` or open the Kanban via `node tracker/serve.mjs`). Known items in `tracker/tickets/` should be surfaced as `(tracked: TASK-{id})` rather than re-surfaced as new.
7. **Actionable findings.** Every issue suggests the skill to invoke for the fix:
   - UISpec drift → `/openbims_ui`
   - Prototype drift → `/openbims_prototype`
   - Mock-data drift → `/openbims_mockdata`
   - Manual drift → `/openbims_docs`
   - Feature-level work → `/openbims_feature`
   - ADR or global concerns → `/openbims_workspace`
