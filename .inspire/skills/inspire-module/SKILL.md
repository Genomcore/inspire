---
name: inspire-module
description: "Lifecycle of a module: create / review / update / scan / delete a module's features and propagate changes across the KB layers. Use when scaffolding a new module, auditing an existing one before a PR, authoring its specs, or removing it."
---

# /inspire_module — Module-level Operations

## Scope

A **module** is a folder `.inspire_kb/02_features/{module}/` that holds an
`_index.md` (the module overview + use-case index) and **one file per use case**
(`{use-case}.md`). This skill owns module-scoped operations and their propagation
across the KB layers: features (`02_features`), screen specs (`05_screens`), the prototype
(`03_prototypes` + `/prototype`), specs (`04_domain`), and ADRs (`01_adr`).

## Invocation

- `/inspire_module review {module}` — full consistency review before PR
- `/inspire_module create {module}` — scaffold a new module across the layers
- `/inspire_module update {module}` — add/remove use cases, restructure, propagate
- `/inspire_module scan {module}` — SDD-layer entry point (surface + author specs)
- `/inspire_module delete {module}` — remove the module and clean every cross-reference

## Subcommand: review

Runs all consistency checks for the module. This is the **required gate before any
PR** that modifies files in `.inspire_kb/02_features/{module}/`.

### 1. Features structure

**Index (`_index.md`):**
- Exists in the module folder.
- Is a **pure index**: overview, module relationships, a **use-case index** table
  linking each use case via `[[wikilinks]]`, and a summary. **No full use-case
  bodies inline.**
- The summary totals match the actual number of use-case files.

**Use-case files:**
- One file per use case (`{use-case}.md`); each carries a back-link
  `[[_index|ModuleName]]` in its intro.
- No orphans (file on disk, not in the index) and no phantoms (in the index, no
  file).
- Feature / use-case IDs are unique within the module and use the module's ID
  prefix (declared in the module `_index.md` / the project's `00_bootstrap`
  conventions).

### 2. screen spec structure

- Folder `.inspire_kb/05_screens/{module}/` with `_index.md` + one file per screen.
- `_index.md` contains the route map + feature-coverage table; every screen in
  the map exists on disk, and every screen file is referenced in the map.
- Every screen header carries `**Features:**` and `**Pattern:**`; every pattern
  resolves to a file in `.inspire_kb/05_screens/patterns/` (or `bespoke` with
  justification).
- No screen redefines design tokens (those live in `design-system.md`); no inline
  mock data (reference the data source); each screen stays focused (~250 lines).

### 3. Quality checks

- **No historical language** anywhere (`"previously"`, `"used to"`,
  `"replaces"`, `"removed"`, `"migrated from"`, strikethrough `~~text~~`, …). The
  KB describes the present state, not its history.
- No embedded ADR content (>~10 lines of rationale without an ADR link).
- All `[[wikilinks]]` resolve (including cross-folder: `patterns/`, `components/`,
  `01_adr/`, `design-system.md`).

### 4. Cross-layer coverage

- **Features ↔ screen spec:** every feature with UI implications has a screen; every
  screen's `**Features:**` line references features that exist in `02_features`;
  the screen spec `_index.md` coverage table aligns with the actual screens.
- **Features ↔ Prototype:** features meant to appear in the horizontal prototype
  are reflected at `/prototype`, and what building them taught is captured in
  `.inspire_kb/03_prototypes/`.
- **Features ↔ Specs:** every feature that describes a behavior has at least one
  realizing action descriptor in `.inspire_kb/04_domain/{module}/` (flag gaps as
  `important`); every action's `## Why` back-sources to a feature via
  `[[wikilink]]` (flag orphan actions as `important`).
- **ADR alignment:** flag anything that contradicts an **accepted** ADR within its
  maturity's reach (see `.inspire_kb/01_adr/`).

### 5. Spec-layer (SDD) checks

Run `.claude/bin/review.sh .inspire_kb/04_domain/{module}/` and incorporate
findings. The rule set covers:
- `acyclic-deps` — no cycles or self-loops in the `requires` graph
- `stable-blockers` — stable actions don't require non-stable targets
- `touched-entity-lifecycle` — stable actions touch only entities ≥ accepted
- `entity-coherence` — per-field type-conflict, unsourced, and orphan-write findings

Render findings via the shared format at
[`.claude/skills/_references/findings-format.md`](../_references/findings-format.md).
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

## Features Structure
- Use-case files: {list}
- Index accuracy: {ok | N mismatches}

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

## Subcommand: create

Scaffold a new module across the layers. The user provides the module name, an ID
prefix (e.g. `MYM`), and a description.

1. **Features folder:** `.inspire_kb/02_features/{module}/`
   - `_index.md` with an overview skeleton + an empty use-case index table.
2. **Register** the module in the top-level `.inspire_kb/02_features/_index.md`
   (if the project keeps one).
3. **screen spec folder:** `.inspire_kb/05_screens/{module}/_index.md` — empty route map +
   feature-coverage tables. No screens yet.
4. Record the module's ID prefix + conventions where the project keeps them (the
   module `_index.md` and/or `.inspire_kb/00_bootstrap`).
5. Point the user to `/inspire_feature create` for the first use cases, and
   `/inspire_prototype` once screens exist.

Report what was created and the next steps.

## Subcommand: update

Modify an existing module. Use for: adding/removing use cases, renaming a feature
ID globally, restructuring, or realigning after a new ADR.

Operate transactionally:
1. Read the current state (features + screen spec + specs).
2. Present the diff proposal to the user.
3. On approval, apply edits across the affected layers.
4. Run `review {module}` to verify no drift was introduced.

## Subcommand: scan

The entry point for SDD-layer work on a module. It surfaces features that lack
realizing specs and chains authoring into `/inspire_domain`. Scan is **read-only**
with respect to `.inspire_kb/04_domain/`; it never authors descriptors itself.

### Phase 1 — Environment setup

Check: are we in a git worktree, on the right per-module SDD branch (e.g.
`feat/sdd-{module}`), with a clean tree? If all yes, proceed. Otherwise surface
the gap and offer, conversationally, to bootstrap a fresh worktree:

```bash
git worktree add .claude/worktrees/sdd-{module} -b feat/sdd-{module} origin/main
```

Direct shell call via the Bash tool. **Do NOT defer to a third-party worktree
skill** — operators may not have it installed; the `inspire-*` skill family must
stay portable.

### Phase 2 — Candidate surfacing + narrowing

Read the module's features:
- `.inspire_kb/02_features/{module}/_index.md` — the use-case index and any action
  declarations.
- `.inspire_kb/02_features/{module}/{use-case}.md` — feature descriptions and the
  actions they declare.

For each declared action (e.g. `platform::actions::resolve`):
- **Canonicalize plural → singular** (`platform::actions::resolve` →
  `platform::action::resolve`). This is a known layer-convention shift — apply it
  silently, don't surface it as a decision.
- Check whether `.inspire_kb/04_domain/{module}/{entity}/{action}.md` exists.
- If not, it's a candidate.

Surface candidates and **dialogue** to narrow the set — one focused question at a
time, show-then-approve. Follow the conversational conventions of
[`/inspire_domain`](../inspire-domain/SKILL.md). Do not enumerate decision-tree
options; let the conversation decide.

### Phase 3 — Chained authoring (only when the operator signals "start")

When the operator has chosen ≥1 action AND explicitly signaled start:
1. Create one `TaskCreate` per chosen action (canonicalized SDD id).
2. Mark the first `in_progress`.
3. Invoke `/inspire_domain define {first-id}` via the Skill tool. `inspire-domain`
   runs its socratic interview from here.
4. On completion, return to this frame and ask whether to continue with the next.

The interview may co-evolve action + entity documents in one `define` invocation;
`/inspire_domain` handles that bipartite walk. Scan's job ends at the handoff.

If the dialogue produces no chosen set (pure exploration), scan ends after Phase 2
without creating tasks. **Scan is valid as pure exploration** — it is not
"first-action-found-triggers-define".

### Phase 4 — Audit report

At the **end** of the report, scan still emits the SDD-layer audit signals:
features without realizing actions, orphan actions (no feature back-source), and
coherence conflicts (via `entity-coherence`). Render via
[`_references/findings-format.md`](../_references/findings-format.md).

`scan {module}` batches over one module; `scan` without args batches over every
module in `.inspire_kb/02_features/`.

## Subcommand: delete

Remove a module across all layers. Use with caution.

1. **Confirm** with the user: list every file and feature about to be deleted.
2. **Features:** delete `.inspire_kb/02_features/{module}/`.
3. **screen spec:** delete `.inspire_kb/05_screens/{module}/`.
4. **Prototype:** remove the module's screens and routes from `/prototype`; prune
   any now-stale learnings in `.inspire_kb/03_prototypes/`.
5. **Specs:** delete `.inspire_kb/04_domain/{module}/`.
6. **Cross-references:**
   - Grep the whole `.inspire_kb/` for `[[{module}]]` or feature-ID references —
     flag and offer fixes.
   - Check ADRs under `.inspire_kb/01_adr/` for references to this module.
   - Check other modules' relationship sections.
7. **Top-level index:** remove from `.inspire_kb/02_features/_index.md` and any
   project-level conventions doc.

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, wikilink slugs, filenames)
> stay verbatim.

1. **`review` is read-only.** It reports, suggests fixes, and recommends other
   skills; it never edits files.
2. **`create` requires user input** for module name, ID prefix, and description.
3. **`update` and `delete` require an explicit plan** presented to the user before
   any edit.
4. **Propagation is mandatory.** A module operation that touches features but
   leaves screen spec / prototype / specs inconsistent is a bug — use the cross-layer
   propagation logic.
5. **Pending drift is acceptable.** Drift items in `## Current prototype` sections
   are informational; don't block PRs unless they contradict an accepted ADR.
6. **Consult the task tracker** at the start of each invocation
   (`/inspire_workspace task list`, or open the Kanban via
   `node .inspire_kb/99_tracker/serve.mjs`). Known items in
   `.inspire_kb/99_tracker/tickets/` are surfaced as `(tracked: TASK-{id})`.
7. **Actionable findings.** Every issue names the skill to invoke for the fix:
   - screen spec drift → `/inspire_screens`
   - Prototype drift → `/inspire_prototype`
   - Feature-level work → `/inspire_feature`
   - ADR or global concerns → `/inspire_workspace`
