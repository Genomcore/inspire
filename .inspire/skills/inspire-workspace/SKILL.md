---
name: inspire-workspace
description: "Workspace-level operations: global review (required pre-PR), ADR lifecycle (create/update/promote/supersede, maturity ladder design→prototyped→implemented), vault structure validation, and the task tracker. Use for cross-cutting concerns that don't belong to a single module or feature."
---

# /inspire_workspace — Workspace-level Operations

## Scope

This skill owns **workspace-scoped** operations:

- **Global review** — the pre-merge gate, orchestrating module-level and
  cross-module checks.
- **ADR lifecycle** — architectural decisions that span ≥2 modules.
- **Vault structure** — `.inspire_kb/02_features/_index.md`,
  `.inspire_kb/01_adr/_index.md`, folder conventions.
- **Task tracker** — `.inspire_kb/99_tracker/tickets/` lifecycle. Open tickets
  live at `.inspire_kb/99_tracker/tickets/*.md`; closed tickets are archived under
  `.inspire_kb/99_tracker/tickets/archive/*.md` so default scans see only active
  work.

## Invocation

### Global review
- `/inspire_workspace review` — full vault review
- `/inspire_workspace review {module1} {module2}` — scoped to selected modules + cross-module checks

### ADR lifecycle

ADR `Status` is a **maturity ladder**, not a binary — it declares how far the
decision has been realized, and therefore how far its consequences should have
propagated (the *propagation contract*):

- `design` — design reasoning. Reach: the whole **design workspace** — features
  (`02_features`) + screens (`05_screens`) + the **horizontal prototype**
  (`/prototype`, a *non-functional* interactive mock) + specs (`04_domain`).
  Refined **in place** on new evidence.
- `prototyped` — additionally **validated in an external functional prototype**:
  real running code in a vertical spike repo has proven the architecture works
  (record it with a `**Prototype:**` pointer to that repo). The horizontal
  prototype does **not** count. Still refined in place.
- `implemented` — additionally realized in the **product codebase**. **Immutable —
  `supersede` to change.**
- `superseded` (by [[x]]) / `rejected` — terminal.

There is no `proposed`/`accepted` state: an ADR present and not
superseded/rejected **is** the current decision at its maturity; the debate
happens in chat before authoring.

- `/inspire_workspace adr create {prefix-slug}` — new ADR (defaults to `Status: design`)
- `/inspire_workspace adr update {id}` — modify an ADR (supersede required only at `implemented`)
- `/inspire_workspace adr promote {id} {maturity}` — advance maturity and propagate consequences
- `/inspire_workspace adr supersede {id} {new-id}` — mark old ADR superseded and wire the wikilink

### Vault structure
- `/inspire_workspace structure` — validate top-level indexes, task tracker, vault conventions

### Task tracker
- `/inspire_workspace task create {title} [--epic X --size M --importance Mid --skills prototype,screens]`
- `/inspire_workspace task update TASK-{id} [--field value ...]`
- `/inspire_workspace task close TASK-{id} [--cancelled --reason "..."]`
- `/inspire_workspace task list [--status X --epic Y --skill prototype]` (read-only)
- `/inspire_workspace task show TASK-{id}`

## Subcommand: review (global)

**REQUIRED** before any PR that modifies files in `.inspire_kb/`. Orchestrates a
full consistency review across all affected modules and the vault structure.

### Execution mode

The **checks, severity model, and output are identical** in both modes — only the
scheduling differs.

- **Sequential (default).** Execute the phases below top-to-bottom in this agent.
- **Workflow (opt-in, when the user enables ultracode / multi-agent).** After
  Phase 1 (scope), run the bundled workflow at
  `.claude/skills/inspire-workspace/review.workflow.mjs` via the **Workflow** tool
  — pass `args: { modules: [<in-scope slugs>] }` and prefer `scriptPath` with that
  file's absolute path. It fans the per-module reviews out in parallel, runs a
  deterministic **completeness gate** (any dropped module review becomes a
  `critical: review-incomplete` finding — never a silent pass), then a single
  synthesizer runs the cross-cutting phases over the **full repo** and emits the
  standard report.

Invariants both modes MUST preserve: **read-only** (flag, never edit, never invoke
a fix-skill); ADR-propagation alignment is judged by reading each ADR's
`Status` + `Decision` — design-workspace coherence (features + screen spec + horizontal
prototype + specs) is required at *every* maturity, and higher maturities add
*external* evidence checkable only by pointer (`prototyped` → a `**Prototype:**`
pointer to an external functional prototype; `implemented` → a codebase reference);
and the output uses the exact skeleton in **Output format** below.

### Phase 1 — Identify scope

- If modules are specified, use those. Otherwise, enumerate all modules listed in
  `.inspire_kb/02_features/_index.md`.
- For each module in scope, delegate to `/inspire_module review {module}`.

### Phase 2 — Module reviews

For each module in scope, the module review performs:
- Features structure (pure `_index.md`, use-case files, index completeness)
- screen spec structure (folder vs legacy monolith, pattern/component compliance)
- Quality checks (no historical language, IDs correct, wikilinks resolve)
- Cross-layer coverage (features ↔ screen spec ↔ prototype ↔ specs)
- Drift consolidation and overengineering detection

### Phase 3 — Cross-module consistency

- **Dependency validation:** feature IDs referenced as dependencies in one module
  exist in the target.
- **ADR references:** all `[[adr-xxx]]` wikilinks resolve to files in
  `.inspire_kb/01_adr/`.
- **ADR propagation alignment:** at *every* maturity, an ADR's consequences must
  cohere across the **in-repo design workspace** (features + screen spec + horizontal
  prototype + specs) — a contradiction there is critical. Higher maturities add
  *external* evidence checked only by pointer, never by inspecting the external
  artifact: `prototyped` needs a `**Prototype:**` pointer; `implemented` a codebase
  reference. A `design` ADR merely lacking external validation is NOT a finding; a
  `design` ADR that contradicts the horizontal prototype IS.
- **No undocumented circular dependencies.**

### Phase 4 — Vault structure

**Features tree:**
- Repo structure matches CLAUDE.md.
- No scripts, `.py`, `.xlsx`, `.deprecated`, or `.DS_Store` files in `.inspire_kb/`.
- Every module folder has `_index.md`.
- `.inspire_kb/01_adr/_index.md` lists all ADR files (no orphans, no phantoms).
- `.inspire_kb/02_features/_index.md` lists all modules.

**screen spec tree:**
- `.inspire_kb/05_screens/design-system.md` exists.
- `.inspire_kb/05_screens/patterns/` and `components/` exist with `_index.md` + files.
- Every pattern/component referenced by a screen exists; no orphans (on disk, not
  referenced).
- Per module: either the folder structure OR a legacy monolith, never both.

### Phase 5 — Prototype component adoption

- Enumerate the shared components catalogued in `.inspire_kb/05_screens/components/`.
- For each, count adoption in the horizontal prototype (`/prototype`): pages using
  the canonical component vs pages still inlining an equivalent.
- Report consolidated drift. High drift is `important` (not critical) — migration
  progresses over time.

### Phase 6 — Catalog coherence

- Patterns catalog: for each pattern file, count references from screens.
- Components catalog: for each component file, count usages in the prototype.
- Flag patterns/components with 0 references (unused or not migrated yet).
- Flag screens claiming a pattern/component that doesn't exist.

### Output format

```markdown
# Global Review | {date}

## Scope
- Modules reviewed: {list}
- screen spec migration status: {N}/{total} migrated

## Summary
{X} issues: {critical} critical, {important} important, {minor} minor
Drift items pending: {N}

## By Module
### {module}
- [{severity}] {description} — {file}:{line} | Fix: `/{skill}`

## Cross-Module
- [{severity}] {description}

## Vault Structure
## Prototype Component Adoption
- {Component}: {adopted}/{total} pages
## Catalog Coherence
- Patterns: {total} defined, {used}, {orphan}
- Components: {total} defined, {used}, {orphan}

## OK
```

### Review rules

1. **Be thorough.** This is the pre-merge gate.
2. **Be specific.** Every finding includes a file path + line number.
3. **Prioritize by impact.** Critical = broken refs, missing files, ADR
   consequences not reflected within their maturity's reach. Important = stale
   content, missing coverage, legacy structure. Minor = naming, formatting.
4. **No false positives.** If unsure, note as "verify".
5. **Actionable.** Every finding suggests the skill to invoke.
6. **Delegate deep dives.** For complex feature-level issues, suggest
   `/inspire_feature review {id}`.
7. **Migration is not failure.** Legacy screen spec monoliths and pending prototype
   drift are `important` (migrate), not `critical`, unless they contradict an ADR
   within its maturity's reach.
8. **Consult the task tracker.** Known items in `.inspire_kb/99_tracker/tickets/`
   are flagged `(tracked: TASK-{id})`. Use `/inspire_workspace task list` or open
   the Kanban via `node .inspire_kb/99_tracker/serve.mjs`.
9. **Required follow-up skills.** When flagging drift, name the mandatory fix skill:
   - Prototype drift → `/inspire_prototype`
   - screen spec drift → `/inspire_screens`
   - Feature drift or ADR misalignment → `/inspire_module update` or
     `/inspire_workspace adr update`

## Subcommand: adr create {prefix-slug}

### Conventions

- **Filename:** `adr-{module-prefix}-{slug}.md` for module-specific, or
  `adr-{slug}.md` for cross-cutting. Slug-only — no numeric prefix.
- **Slug uniqueness:** unique within a prefix; cross-cutting slugs unique
  vault-wide.
- **Location:** `.inspire_kb/01_adr/`.
- **Canonical ID:** the filename (without `.md`). The H1 is the human title.

**Rationale.** Numeric prefixes collide under parallel work (two branches grab the
same next number). Slug-only filenames are collision-free by construction
(mirroring the `TASK-{id}` convention).

### Template

```markdown
# {Title}

**Status:** design
**Modules affected:** [[module-a]], [[module-b]]
<!-- Status maturity ladder: design | prototyped | implemented | superseded by [[x]] | rejected.
     design = the design workspace (features + screen spec + horizontal prototype + specs).
     prototyped = validated in an EXTERNAL functional prototype (a vertical spike repo,
       NOT the horizontal prototype) — add: **Prototype:** `repo-or-env` — what it validated. -->

## Context
What problem or question prompted this decision.

## Decision
What we decided and why.

## Consequences
What follows — positive and negative. Include breaking changes.

### Breaking changes
- ...

## Alternatives considered
1. **{alternative}.** Why rejected.

## Related ADRs
- [[adr-xxx]] — {relation}
```

### Steps

1. **Ask** the user: short title, modules affected, context, the decision, key
   consequences, alternatives considered.
2. **Write the ADR file** at the computed path.
3. **Update `.inspire_kb/01_adr/_index.md`** — add a row to the appropriate module
   section (or Transversales for cross-cutting).
4. **Propose ADR references** in the feature files that should link to it: list
   files to edit, wait for approval.
5. Set `**Status:** design` by default. Use `adr promote` later to advance.

## Subcommand: adr update {id}

Modify an ADR in place. At `design` / `prototyped` maturity this is the **normal
path** — freely edit any section, including `Decision`; record new evidence (e.g. a
`**Prototype:**` pointer) when it drove the change.

**Only at `Status: implemented`** does a change to the `Decision` section require
`supersede` (product code depends on it — preserve the audit trail): present a
warning and offer to switch approach. `supersede` also stays available at any
maturity for a genuine reversal you want recorded as a distinct decision.

## Subcommand: adr promote {id} {maturity}

Advance an ADR along `design → prototyped → implemented` and propagate its
consequences to the layers the new maturity reaches.

1. Verify the ADR exists and the transition is a **forward** step. Reject skips and
   downgrades — refine the `Decision` in place with `adr update` instead.
2. Update `**Status:** {maturity}`. For `prototyped`, require a `**Prototype:**`
   pointer (which external repo validated it, and the evidence); for `implemented`,
   note where in the codebase it lives.
3. **Propagate / record evidence:** confirm the design workspace reflects the
   decision, then for each affected module invoke `/inspire_module review {module}`
   to detect where the ADR's consequences are not yet reflected. Surface the gaps
   as follow-up actions.

## Subcommand: adr supersede {id} {new-id}

Replace an ADR with a new one that changes its decision (create the new ADR first
via `adr create`).

1. Verify both ADRs exist (the old one at any non-terminal maturity).
2. Update the old ADR: `**Status:** superseded by [[{new-id}]]`.
3. Update the new ADR's header: `Supersedes: [[{old-id}]]`.
4. Grep `.inspire_kb/` for references to the old ADR; propose updates.
5. Update `.inspire_kb/01_adr/_index.md` (move the old entry to the superseded
   section).

## Task tracker format

Tickets live as one file per ticket. The `.md` files are the **only source of
truth** — no generated indexes or caches.

### Storage layout

- **Open tickets** → `.inspire_kb/99_tracker/tickets/TASK-{id}.md`
- **Closed tickets** (`status` ∈ {`Done`, `Cancelled`}) →
  `.inspire_kb/99_tracker/tickets/archive/TASK-{id}.md`

The archive subfolder keeps the active set lean: agents scanning "what's pending"
read only `.inspire_kb/99_tracker/tickets/*.md` (top-level, non-recursive). The
Kanban web (`.inspire_kb/99_tracker/serve.mjs`) reads both locations. `task close`
moves the file; `task show` / `task update` look in `tickets/` first, then
`tickets/archive/`.

### Frontmatter schema

```yaml
---
id: TASK-a3k7m2                    # 6 chars base36 random, must match filename
title: Migrate screen spec X to pattern-driven
created: 2026-05-07                # YYYY-MM-DD
updated: 2026-05-07                # auto-updated by skill on each change
reporter: "@handle"                # git handle
closed_by: null                    # @handle when status ∈ {Done, Cancelled}
closed_at: null                    # YYYY-MM-DD when status ∈ {Done, Cancelled}
epic: {module-or-area}             # see enum below
size: M                            # S | M | L | XL
importance: High                   # Very Low | Low | Mid | High | Very High
skills: [prototype, screens]            # which layer skills execute the work
status: Open                       # Open | Done | Cancelled
blocked_by: []                     # list of ticket / feature / ADR IDs
related_to: [TASK-xxx]             # list of IDs
---

## Description
...free body markdown; suggested: Description / Acceptance criteria / Notes...
```

### Enums

- **`epic`**: a **project-defined** slug — usually a module from
  `.inspire_kb/02_features/`, plus cross-cutting areas. Recommended baseline:
  `workspace | meta | tooling | docs | skill-feedback`, extended with the
  project's own module slugs.
- **`size`**: `S | M | L | XL`
- **`importance`**: `Very Low | Low | Mid | High | Very High`
- **`status`**: `Open | Done | Cancelled` — there is no in-flight state. `Open` =
  not yet done, `Done` = completed and verified, `Cancelled` = won't do (reason in
  body).
- **`skills`** (multi-select, may be empty): `bootstrap | module | feature |
  domain | screens | prototype | workspace` — which layer skills cover the work. `[]`
  means the work doesn't map to a layer skill (tooling, ops, packaging).

### Skill-feedback tickets (convention)

When a skill's usage produces a friction signal worth capturing — operator
pushback, a recurring `AskUserQuestion` that should default, drift from what the
skill anticipated — file a standard ticket:

```yaml
epic: skill-feedback
skills: [<source-skill>]
size: S
importance: Low
```

**Title format:** `{skill-name}: <short friction observation>`. **Body:**
`## Observation` · `## Where it surfaced` · `## Suggested follow-up`. It reuses
standard ticket infrastructure — no new tooling; the operator decides when an
observation deserves a ticket, and skills surface candidates conversationally.

### ID scheme

Format: `TASK-` + 6 chars from `[a-z0-9]` (base36). Example: `TASK-a3k7m2`.

- **Generation:** random. 36⁶ ≈ 2.18B combinations; collision at 10k tickets ≈ 10⁻⁵.
- **Defense in depth:** before writing, verify the file doesn't exist; regenerate
  on the improbable collision.
- **Concurrency:** no coordination needed — random IDs effectively never collide.
- **Stable forever:** cancelled tickets keep their ID; IDs are never reused.

### Subcommand: task create {title} [--flags]

1. Resolve `@handle` from `git config user.email` (cached per session).
2. Resolve today's date from CLAUDE.md `currentDate` or `date +%Y-%m-%d`.
3. Generate a random 6-char base36 ID; verify the file doesn't exist; regenerate
   if it does.
4. Apply flags `--epic` (required), `--size` (default M), `--importance` (default
   Mid), `--skills` (comma-separated, default empty), `--status` (default Open),
   `--blocked-by`, `--related-to`.
5. Write the file with frontmatter + an empty `## Description` body (or `--body`).
6. Print the new ID to stdout.

### Subcommand: task update TASK-{id} [--flags]

1. Resolve the ticket path (`tickets/` then `tickets/archive/`). Error if neither.
2. Apply flag changes (validate against enums).
3. Set `updated` to today.
4. **Status transitions move the file:**
   - New `status` ∈ {`Done`, `Cancelled`} and file in `tickets/` → write to
     `tickets/archive/` and remove the original; fill `closed_by` / `closed_at`.
   - Back to `Open` from `tickets/archive/` → write to `tickets/`; clear
     `closed_by` / `closed_at`.
   - Otherwise, write in place.
5. Show a diff before saving.

### Subcommand: task close TASK-{id} [--cancelled --reason "..."]

Shortcut that transitions an open ticket to a closed status and archives it:
default `status: Done`; with `--cancelled`, `status: Cancelled` (append a
`## Cancellation reason` if `--reason` given). Sets `closed_by` / `closed_at` /
`updated`, and **moves the file** to `tickets/archive/`.

### Subcommand: task list [--filter]

1. Scan `.inspire_kb/99_tracker/tickets/*.md` (top-level, non-recursive — excludes
   `archive/`). Parse frontmatter.
2. With `--include-archived` (or `--all`), also scan `tickets/archive/*.md`.
3. Filters: `--status`, `--epic`, `--size`, `--importance`, `--reporter`,
   `--skill` (matches if `skills` contains the value), `--blocked`.
4. Print a compact table to stdout: `id | status | epic | size | importance |
   skills | title`.
5. Read-only.

### Subcommand: task show TASK-{id}

Read the file (`tickets/` then `tickets/archive/`) and print frontmatter + body.
Read-only.

### Rules

1. **One file per ticket.** Filename = `TASK-{id}.md`; the `id` field matches.
2. **IDs never reused.** Don't delete files — archive them.
3. **Open vs archived location is derived from `status`.** The skill keeps location
   consistent with `status` on every transition.
4. **`updated` is auto-managed.** Don't edit it by hand.
5. **`closed_by` / `closed_at` only when status ∈ {Done, Cancelled}.**
6. **Body markdown is free.** Description / Acceptance criteria / Notes suggested.
7. **Concurrent edits are safe** — random IDs, no locking.
8. **Server is read-only.** `.inspire_kb/99_tracker/serve.mjs` never writes; it
   scans both `tickets/` and `tickets/archive/`.

## Subcommand: structure

Validate the vault structure at the top level (not module-scoped).

### Checks

1. **CLAUDE.md** is present at the workspace root.
2. **Top-level indexes:**
   - `.inspire_kb/02_features/_index.md` lists every module.
   - `.inspire_kb/01_adr/_index.md` lists every ADR.
   - Each module folder has `_index.md`.
3. **Task tracker:**
   - `.inspire_kb/99_tracker/tickets/` has valid `.md` files at top level (open)
     and under `archive/` (closed). Frontmatter parses, enums match, ID format
     `TASK-[a-z0-9]{6}`.
   - `id` matches filename; no duplicate IDs across `tickets/` and `archive/`.
   - **Location ↔ status invariant:** every top-level ticket is `Open`; every
     archived ticket is `Done`/`Cancelled`.
   - `.inspire_kb/99_tracker/serve.mjs` present.
   - `blocked_by` / `related_to` references to other `TASK-*` IDs resolve (warning
     if not).
4. **No orphan files:** no stale `.md` at `.inspire_kb/` root (except
   `CONTRIBUTING.md` if present); no legacy paths.

### Output

```markdown
# Vault Structure | {date}

## Top-level indexes
- .inspire_kb/02_features/_index.md: {ok | N issues}
- .inspire_kb/01_adr/_index.md: {ok | N issues}

## Module folders
- Modules with _index.md: {N}/{total}

## Task tracker
- tickets/: {N} open
- tickets/archive/: {N} closed ({Done: N, Cancelled: N})
- serve.mjs: {present | missing}

## Issues
- [{severity}] {description}

## OK
```

## Rules

1. **`review` is read-only.** It suggests; it does not edit files.
2. **ADR maturity is explicit.** Advancing `design → prototyped → implemented`
   requires `adr promote`; `create` defaults to `design`.
3. **Only `implemented` ADRs are immutable in content.** Supersede to change their
   `Decision`; `design` / `prototyped` ADRs are refined in place with `adr update`.
4. **Propagate to the maturity's reach.** Design-workspace coherence (features +
   screen spec + horizontal prototype + specs) is required at every maturity;
   `prototyped` adds a pointer to an external functional prototype, `implemented` a
   codebase reference. The skill surfaces gaps within that reach.
5. **Grep references on rename/supersede.** Always scan the vault when renaming an
   ADR or changing its ID.
6. **Consult the task tracker.** Known items live in
   `.inspire_kb/99_tracker/tickets/`; don't re-report them as new findings.
7. **No historical language in ADRs.** ADRs describe the decision context at the
   time it was made; don't narrate migration history.
