---
name: inspire-feature
description: "Lifecycle of a feature / use case: create / review / update / delete a use-case file in a module and propagate across the KB layers. Use when adding, auditing, or removing features."
---

# /inspire_feature — Feature-level Operations

## Scope

A **feature** is a use case, captured as a file
`.inspire_kb/03_features/{module}/{use-case}.md` and indexed in that module's hub
`02_modules/{module}.md`. This skill owns feature-scoped operations and their propagation
across the KB layers: screens (`05_screens`), prototype (`/prototype`),
specs (`04_domain`), and ADRs (`01_adr`).

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
   `.inspire_kb/03_features/{module}/`. Read: description, actor/personas,
   dependencies, priority, state, ADRs referenced. Identify the module from the
   folder.
2. **screen spec coverage.** In `.inspire_kb/05_screens/{module}/`, search each screen's
   `**Features:**` line for this feature ID; cross-reference the screen spec `_index.md`
   coverage table. Flag if no screen covers a UI-facing feature; note "No UI
   expected" for backend/infrastructure features.
3. **Prototype coverage.** For each covering screen, verify it is reflected in the
   horizontal prototype at `/prototype`, and note drift (pending component
   adoption, hardcoded data, ADR gaps). Insights land in the specs / screens / ADRs,
   not a prototype learnings file.
4. **Specs (SDD) coverage.** Find action descriptors whose `## Why` wikilinks back
   to this feature. Search `.inspire_kb/04_domain/**/*.md` for `[[{feature-id}]]`.
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
| Feature (03_features) | ✅ | {file} |
| screen spec (05_screens) | ✅/❌/N/A | Screens: {list} |
| Prototype (/prototype) | ✅/⚠️/❌/N/A | Drift: {count} |
| Specs (04_domain) | ✅/❌/N/A | Actions: {list} |
| ADR alignment | ✅/⚠️/❌ | |

## Issues
- [{severity}] {description} — {file}:{line} | Fix: `/{skill}`

## OK
```

### Batch mode (module)

Reviews ALL features of a module in parallel.

1. Read the module's hub `02_modules/{module}.md` and extract all feature/use-case IDs from its
   use-case index.
2. Present the list to the user and **ask for confirmation** before proceeding.
3. On confirmation, **launch one Agent per feature in parallel** — each runs the
   single-feature review.
4. Collect results.
5. **Synthesize** a consolidated report: aggregated coverage matrix, issues grouped
   by severity, and patterns (e.g. "5 features missing screen spec coverage").
6. If issues are found, present a **correction plan**: ordered actions grouped by
   the skill to invoke.

**Output format (batch):**

```markdown
# Feature Review: {module} (batch) | {date}

## Scope
{N} features reviewed: {list}

## Aggregated Coverage Matrix
| Feature | 03_features | screen spec | Prototype | Specs | ADR |
|---------|-------------|--------|-----------|-------|-----|
| PRV-01  | ✅          | ✅     | ⚠️ (3)    | ❌    | ✅  |
| ...     |             |        |           |       |     |

## Summary
- Full coverage: {N} · Gaps: {N} · Drift items pending: {count}

## Issues by Severity
### Critical / Important / Minor

## Correction Plan
1. `/inspire_screens` — Add screens for: {list}
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
   `.inspire_kb/04_domain/{module}/{entity}/{action}.md`, and dialogue with the
   operator to pick a set. One focused question at a time; follow the
   conversational conventions of [`/inspire_domain`](../inspire-domain/SKILL.md).
3. **Chained authoring** (only on an explicit "start" signal) — create one
   `TaskCreate` per chosen action, mark the first `in_progress`, and invoke
   `/inspire_domain define {id}` via the Skill tool; `inspire-domain` runs its
   socratic interview and may co-evolve the action + entity documents in one flow.

Scan is read-only with respect to `.inspire_kb/04_domain/`; authoring lives in
`/inspire_domain`. Pure exploration leaves no tasks created. **Batch mode**
(`scan {module}`) expands this over every feature in the module's hub `02_modules/{module}.md`.

### Phase 4 — Audit report

After the dialogue, scan surfaces per-feature audit findings: features with no
realizing action, partial realization, and lifecycle mismatch (feature marked
implemented but realizing actions still `lifecycle: draft`). Render via
[`_references/findings-format.md`](../_references/findings-format.md).

## Subcommand: create

Create a new feature/use-case file in a module. **Required arg:**
`{module}/{feature-id}` (e.g. `ai-agents/AIA-08`).

1. **Verify** the module exists (`.inspire_kb/02_modules/{module}.md`).
2. **Ask** the user: name, description (2–5 sentences), actor/personas,
   dependencies (other feature IDs), priority (Core / Important / Nice-to-have),
   state (🟡 Planned default), ADRs to reference.
3. **Run the acceptance-criteria quality gate** (below) on the criteria before
   writing, then **create the use-case file**
   `.inspire_kb/03_features/{module}/{feature-id}.md` from the template below.
4. **Update the module hub** (`02_modules/{module}.md`) — add the row to its
   use-case index and fix the totals.
5. **Report next steps:**
   - If UI-facing → `/inspire_screens` to add a screen spec.
   - If it describes a behavior/endpoint → `/inspire_domain define
     {module}::{entity}::{verb}` to author the action descriptor.
   - Prototype → `/inspire_prototype` when ready.

**Feature ID convention:** the module's prefix + the next available number (scan
existing IDs), per the convention recorded in the module hub /
`00_bootstrap`.

## Subcommand: update

Modify an existing feature. Use for: changing the description, adding/removing
dependencies, promoting priority, changing state
(`🟡 Planned` → `🔵 In progress` → `🟢 Implemented`), or renaming.

1. Read the current use-case file.
2. Present a diff proposal to the user. If the `## Acceptance criteria` change, run
   them through the acceptance-criteria quality gate (below) before proposing.
3. On approval, apply it.
4. If renamed: update the module hub `02_modules/{module}.md`, and grep `.inspire_kb/` (and any
   project code) for references to the old ID and offer fixes.
5. Run `review {feature-id}` to verify no drift.

## Subcommand: delete

Remove a feature and clean up all references.

1. **Confirm** with the user: list every file touching this feature.
2. Delete the use-case file
   (`.inspire_kb/03_features/{module}/{feature-id}.md`).
3. Remove its row from the module hub `02_modules/{module}.md` and fix the totals.
4. **screen spec:** remove the feature ID from any screen's `**Features:**` line; if a
   screen's only feature was this one, flag it for removal (that's `/inspire_screens`'s
   job) and update the screen spec `_index.md` coverage table.
5. **Prototype:** remove references in `/prototype`; note any
   `.inspire_kb/06_spikes/` entry that referenced this feature.
6. **ADRs:** grep `.inspire_kb/01_adr/`; if an ADR mentions this feature, flag it —
   may need an ADR update.

## Use case template

Use this template at `.inspire_kb/03_features/{module}/{feature-id}.md`:

```markdown
# {FEATURE-ID}: {Feature Name}

> Source: [[../../02_modules/{module}]]

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

## Acceptance-criteria quality gate

Acceptance criteria are the contract the coding stage tests against
([`/inspire_code tdd`](../inspire-code/SKILL.md) turns each testable criterion into
a test). Weak criteria leak into weak tests and rework. So whenever criteria are
authored or changed — in `create` (before writing) and in `update` (when the
`## Acceptance criteria` change) — pass them through this gate first, as a Senior
Technical Product Owner would. It is a **judgment gate, not a subcommand**: run it
inline, show the operator what you'd tighten, and only write once the criteria hold.

Check each criterion on three dimensions:

- **Complete** — states the input/context, the expected observable outcome, and the
  error/edge behavior. Implicit requirements made explicit; scope (in / out) clear.
- **Testable** — a concrete test can be written from it alone; the result is
  measurable and observable; boundaries defined (empty, min, max, null); clear
  pass/fail. **Flag vague language** — "fast", "user-friendly", "appropriate", "as
  needed", "etc." — and replace it with a number or a concrete condition.
- **Verifiable** — checkable without reading the implementation; describes WHAT not
  HOW (stays functional, per Rule 3); no contradictions between criteria; happy
  path **and** error/edge paths covered.

Then a short **devil's advocate** pass — name at least a couple of ways the feature
could break that the criteria don't yet cover (malformed/missing data, an external
dependency down, two actors acting at once, boundary inputs) and turn each into a
missing criterion or an explicit out-of-scope note. Watch for **scope creep**: a
criterion that adds a requirement nobody asked for is a flag, not a feature.

Surface gaps concisely (e.g. `AC-2: "should be fast" → define: p95 < 200 ms`);
tighten with the operator; write the criteria only once they pass. A criterion that
cannot be made testable is usually a spec/design gap — resolve it here, or, if it
depends on a behavioral contract, chain to `/inspire_domain`.

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, wikilink slugs, filenames)
> stay verbatim.

1. **The use-case file is the source of truth.** Everything else (screen spec,
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
7. **Drift is informational.** `## Current prototype` drift items don't block
   reviews unless they contradict an accepted ADR.
8. **Batch synthesis.** In batch review, identify patterns and produce a
   prioritized correction plan grouped by fix skill.
9. **Consult the task tracker** (`/inspire_task list`, or
   `node .inspire_kb/99_tracker/serve.mjs`) for tracked drift; don't re-surface it
   as new.
10. **Acceptance criteria pass the quality gate before they land.** `create` and
    `update` run the gate above; criteria that can't be made testable signal a
    spec/design gap to resolve (here or via `/inspire_domain`), not something to
    write as-is.
