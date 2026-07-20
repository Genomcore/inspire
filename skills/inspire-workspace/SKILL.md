---
name: inspire-workspace
description: "Workspace-level operations: global review (required pre-PR), ADR lifecycle (create/update/promote/supersede, maturity ladder design→prototyped→implemented), vault structure validation. Use for cross-cutting concerns that don't belong to a single module or feature."
---

# /inspire_workspace — Workspace-level Operations

## Scope

This skill owns **workspace-scoped** operations. It covers:

- **Global review** — the pre-merge gate, orchestrating module-level and cross-module checks
- **ADR lifecycle** — architectural decisions that span ≥2 modules
- **Vault structure** — `spec/pdd/_index.md`, `spec/adrs/_index.md`, folder conventions, task tracker
- **Task tracker** — `tracker/tickets/` lifecycle (create, update, close, list, show). Open tickets live at `tracker/tickets/*.md`; closed tickets are archived under `tracker/tickets/archive/*.md` so the agent's default scans only see active work.

## Invocation

### Global review
- `/inspire_workspace review` — full vault review
- `/inspire_workspace review {module1} {module2}` — scoped to selected modules + cross-module checks

### ADR lifecycle

ADR `Status` is a **maturity ladder**, not a binary — it declares how far the decision has been realized and therefore how far its consequences should have propagated (the *propagation contract*):

- `design` — design reasoning. Reach: the whole **design workspace** — PDD + UISpec + the interactive console prototype (a *non-functional* "Figma interactivo") + mock-data + manual. In this repo, design already *includes* the prototype. Decision is refined **in place** on new evidence.
- `prototyped` — additionally **validated in an external functional prototype**: real running code in an external environment has proven the architecture works (record it with a `**Prototype:**` pointer). The interactive console does **not** count. Decision still refined in place.
- `implemented` — additionally realized in the **product codebase**. Decision is **immutable — `supersede` to change**.
- `superseded` (by [[x]]) / `rejected` — terminal.

There is no `proposed`/`accepted` state: an ADR present and not superseded/rejected **is** the current decision at its maturity; the debate happens in chat before authoring.

- `/inspire_workspace adr create {prefix-slug}` — new ADR (defaults to `Status: design`)
- `/inspire_workspace adr update {id}` — modify an existing ADR (supersede required only at `implemented`)
- `/inspire_workspace adr promote {id} {maturity}` — advance maturity (`design`→`prototyped`→`implemented`) and propagate consequences
- `/inspire_workspace adr supersede {id} {new-id}` — mark old ADR superseded and wire the wikilink

### Vault structure
- `/inspire_workspace structure` — validate top-level indexes, task tracker, vault conventions

### Task tracker
- `/inspire_workspace task create {title} [--epic X --size M --importance Mid --skills prototype,ui]` — create a new ticket as `tracker/tickets/TASK-{id}.md` (status defaults to `Open`)
- `/inspire_workspace task update TASK-{id} [--field value ...]` — modify a ticket's frontmatter
- `/inspire_workspace task close TASK-{id} [--cancelled --reason "..."]` — set status to Done (default) or Cancelled
- `/inspire_workspace task list [--status X --epic Y --skill prototype]` — list filtered tickets to stdout (read-only)
- `/inspire_workspace task show TASK-{id}` — print a ticket in full

## Subcommand: review (global)

**REQUIRED** before any PR that modifies files in `spec/`. Orchestrates a full consistency review across all affected modules and the vault structure.

### Execution mode

This review runs in one of two modes; the **checks, severity model, and output are identical** either way — only the scheduling differs.

- **Sequential (default).** Execute Phases 1–7 below top-to-bottom in this agent. Use this when not in a multi-agent context.
- **Workflow (opt-in, when the user enables ultracode / multi-agent).** After Phase 1 (scope), run the bundled workflow at `.claude/skills/inspire-workspace/review.workflow.mjs` via the **Workflow** tool — pass `args: { modules: [<in-scope slugs>] }` and prefer `scriptPath` with that file's absolute path (or read it and pass the contents as `script` if your harness requires inline scripts). It fans the per-module reviews out in parallel (Phase A), runs a deterministic **completeness gate** (any dropped or degenerate module review becomes a `critical: review-incomplete` finding — never a silent pass), then a single synthesizer runs the cross-cutting Phases 3–7 over the **full repo** (scope narrows only the module fan-out) and emits the standard report. v1 keeps Phases 3–7 sequential inside the synthesizer.

Invariants both modes MUST preserve: **read-only** (flag, never edit, never invoke a fix-skill); ADR-propagation alignment is judged by the synthesizer/orchestrator reading each ADR's `Status`+`Decision` (the per-module review does not read ADR status): design-workspace coherence (PDD + UISpec + console prototype + mock + manual) is required at *every* maturity, and maturity adds *external* evidence checkable only by pointer — `prototyped` a `**Prototype:**` pointer to an external functional prototype, `implemented` a codebase reference; the **three ADR-UX grep gates run as literal greps** (deterministic); and the output uses the exact skeleton in **Output format** below.

### Phase 1 — Identify scope

- If modules are specified, use those. Otherwise, enumerate all 12 core modules + satellites listed in `spec/pdd/_index.md`.
- For each module in scope, delegate to `/inspire_module review {module}`.

### Phase 2 — Module reviews

For each module in scope, the module-review performs:
- PDD structure (pure `_index.md`, submodule files, feature completeness)
- UISpec structure (new folder vs legacy monolith, pattern/component compliance)
- Quality checks (no historical language, IDs correct, wikilinks resolve)
- Cross-layer coverage (PDD ↔ UISpec ↔ Prototype ↔ Mock ↔ Manual)
- Drift consolidation
- Overengineering detection

### Phase 3 — Cross-module consistency

Checks that span multiple modules:

- **Dependency validation:** feature IDs referenced as dependencies in one module exist in the target
- **ADR references:** all `[[adr-xxx]]` wikilinks in PDDs resolve to existing ADR files in `spec/adrs/`
- **ADR propagation alignment:** at *every* maturity, an ADR's consequences must cohere across the **in-repo design workspace** (PDD + UISpec + console prototype + mock + manual) — a contradiction there is critical. Maturity adds *external* evidence the review checks only by pointer, never by inspecting the external artifact: `prototyped` needs a `**Prototype:**` pointer (external functional prototype), `implemented` a codebase reference. A `design` ADR simply lacking external validation is NOT a finding; a `design` ADR that contradicts the console prototype IS. Example: ADR-AIA-01 → `agents.md` describes refs-only composition and the AI Agents UISpec must NOT describe inline permissions.
- **Satellite references:** satellite PDDs reference valid core module feature IDs
- **Marketplace coherence:** artifact types declared by Marketplace match what other modules register as installable
- **No circular dependencies** that aren't documented

### Phase 4 — Vault structure

**PDD tree:**
- Repo structure matches CLAUDE.md
- No scripts, `.py`, `.xlsx`, `.deprecated` files in `spec/`
- No `.DS_Store` files in `spec/`
- Every core module folder has `_index.md`
- `spec/adrs/_index.md` lists all ADR files (no orphans, no phantoms)
- `spec/pdd/_index.md` lists all modules (core + satellite)
- Every core module (12) has: PDD folder, manual page, UISpec (if UI-facing)
- Every satellite has: PDD in `spec/pdd/satellite/`

**UISpec tree:**
- `spec/specs/ui/openbims-console/design-system.md` exists
- `spec/specs/ui/openbims-console/patterns/` exists with `_index.md` + files per pattern
- `spec/specs/ui/openbims-console/components/` exists with `_index.md` + files per component
- Every pattern referenced by a screen exists
- Every component referenced by a screen exists
- No orphan patterns/components (exist on disk but not referenced)
- Per module: either new folder structure OR legacy monolith, never both

**Manual tree:**
- Every `manual/modules/*.html` corresponds to a real module
- No orphan manual pages

### Phase 5 — Mock data integrity

- Every `.sql` schema file parses without syntax errors
- Every table defined in schema has a corresponding `.jsonl` in `mock-data/tables/`
- No orphan `.jsonl` files
- `mock-data/views/*.sql` reference only existing tables
- FK references across schemas resolve
- `code/*/scripts/sync-data.sh` points to correct paths (`mock-data/`, not legacy `specs/mock-data/`)
- **Centralized logging gate** (per [[adr-audit-01-centralized-logging]]): no schema outside `audit/` may define tables matching `*_audit_events`, `*_logs`, `*_activity_log`. Grep:
  ```bash
  grep -rniE "CREATE TABLE.*_(audit_events|activity_log|audit_log|logs_table)" mock-data/schema/ | grep -v audit
  ```
  Any match is a violation. Also: no route `/{module}/audit` in `App.jsx` except for the `audit` module; no sidebar entry "Audit Trail" under a non-audit module.
- **Module landing pages gate** (per [[adr-ux-01-module-landing-pages]]): `/{module}` must be a `<Navigate>` redirect or a tabbed page, never a dashboard. Check:
  ```bash
  grep -nE 'Route path="/[a-z-]+" element=\{<[A-Z][A-Za-z]*Dashboard' code/openbims-console/src/App.jsx
  grep -nE '"Dashboard"|"Overview"' code/openbims-console/src/components/layout/Sidebar.jsx | grep -v "/audit"
  ```
  Any `{Module}Dashboard` rendered at `/{module}` or "Dashboard"/"Overview" sidebar entry at module root is a violation. Exception: dashboards scoped to a specific resource (`/{module}/{resource}/:id/analytics`) or to a subsystem with its own page route.
- **Module-level settings gate** (per [[adr-ux-02-settings-location]]): no functional module may have `/{module}/settings` as a dedicated page, nor a sidebar "Settings" entry. Check:
  ```bash
  grep -nE 'Route path="/[a-z-]+/settings" element=\{<[A-Z][A-Za-z]*Settings' code/openbims-console/src/App.jsx
  grep -nE 'label: "Settings".*path: "/[a-z-]+"' code/openbims-console/src/components/layout/Sidebar.jsx | grep -v "/platform"
  ```
  Any `{Module}Settings` page route outside Platform or a "Settings" sidebar entry under a functional module is a violation. Allowed: a redirect `/{module}/settings` → `/{module}/{resource}?tab=settings` for backward compat. Exception: Platform module is the canonical home for cross-module settings.

### Phase 6 — Prototype component adoption

- Enumerate components in `code/openbims-console/src/components/shared/`
- For each canonical component, count adoption: N pages using it vs M pages still inlining equivalent
- Report consolidated drift
- High drift is `important` (not critical) — migration progresses over time

### Phase 7 — Catalog coherence

- Patterns catalog: for each pattern file, count actual references from screens
- Components catalog: for each component file, count React imports
- Flag patterns/components with 0 references (either unused or not migrated yet)
- Flag screens claiming to use a pattern/component that doesn't exist

### Output format

```markdown
# Global Review | {date}

## Scope
- Modules reviewed: {list}
- UISpec migration status: {N}/{total} migrated

## Summary
{X} issues: {critical} critical, {important} important, {minor} minor
Drift items pending: {N}

## By Module
### {module}
- [{severity}] {description} — {file}:{line} | Fix: `/{skill}`

## Cross-Module
- [{severity}] {description}

## Vault Structure
## Mock Data Integrity
## Prototype Component Adoption
- {Component}: {adopted}/{total} pages
## Catalog Coherence
- Patterns: {total} defined, {used}, {orphan}
- Components: {total} defined, {used}, {orphan}

## OK
```

### Review rules

1. **Be thorough.** This is the pre-merge gate.
2. **Be specific.** Every finding includes file path + line number.
3. **Prioritize by impact.** Critical = broken refs, missing files, ADR consequences not reflected within their maturity's reach. Important = stale content, missing coverage, legacy structure. Minor = naming, formatting.
4. **No false positives.** If unsure, note as "verify".
5. **Actionable.** Every finding suggests the skill to invoke.
6. **Delegate deep dives.** For complex feature-level issues, suggest `/inspire_feature review {id}`.
7. **Migration is not failure.** Legacy UISpec monoliths and pending prototype drift are `important` (migrate), not `critical`, unless they contradict an ADR within its maturity's reach.
8. **Consult the task tracker.** Known items in `tracker/tickets/` should be flagged `(tracked: TASK-{id})`. Use `/inspire_workspace task list` or open the Kanban via `node tracker/serve.mjs`.
9. **Required follow-up skills.** When flagging drift, explicitly call out the fix skill as mandatory before PR:
   - Prototype drift → `/inspire_prototype`
   - UISpec drift → `/inspire_ui`
   - PDD drift or ADR misalignment → `/inspire_module update` or `/inspire_workspace adr update`

## Subcommand: adr create {prefix-slug}

Create a new ADR.

### Conventions

- **Filename:** `adr-{module-prefix}-{slug}.md` (e.g., `adr-ure-scheduler.md`) for module-specific, or `adr-{slug}.md` for cross-cutting (e.g., `adr-interop-pattern.md`). Slug-only — no numeric prefix.
- **Slug uniqueness:** slugs are unique within their prefix; cross-cutting slugs are unique vault-wide.
- **Location:** `spec/adrs/`
- **Canonical ID:** the filename (without `.md`). Do not duplicate an `ADR-{CODE}` in the H1 — the H1 is the human title.

**Rationale.** Numeric prefixes are collision-prone under parallel work: two branches can independently grab the same next number, producing semantic conflicts that don't surface as textual conflicts at merge time. Slug-only filenames are collision-free by construction (mirroring the `TASK-{id}` ticket convention). See TASK-t4mxqz.

### Template

```markdown
# {Title}

**Status:** design
**Modules affected:** [[module-a]], [[module-b]]
<!-- Status maturity ladder: design | prototyped | implemented | superseded by [[x]] | rejected.
     design = the design workspace (PDD + UISpec + interactive console prototype + mock + manual).
     prototyped = validated in an EXTERNAL functional prototype (real code, NOT the console) — add:
       **Prototype:** `repo-or-env` — what it validated. -->

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

1. **Ask** the user:
   - Short title
   - Which modules are affected (must match real modules)
   - Brief context
   - The decision
   - Key consequences
   - Alternatives considered
2. **Write the ADR file** at the computed path
3. **Update `spec/adrs/_index.md`**: add a row to the appropriate module section (or Transversales for cross-cutting)
4. **Propose ADR references in PDDs** that should link to this ADR: list files to edit, wait for approval
5. Set `**Status:** design` by default (the entry maturity). Use `adr promote` later to advance as the decision is prototyped / implemented.

## Subcommand: adr update {id}

Modify an existing ADR in place. At `design` / `prototyped` maturity this is the **normal path** — decisions are refined as design and prototyping evidence accrues; freely edit any section, including `Decision`. Record the new evidence (e.g. a `**Prototype:**` pointer) when it drove the change.

Valid updates at any maturity:
- Typos, formatting, clarifications
- Updating the `Modules affected` list
- `Decision` / `Consequences` / `Alternatives` refinements (at `design` / `prototyped`)

**Only at `Status: implemented`** does a change to the `Decision` section require `supersede` (product code depends on it — preserve the audit trail): present a warning and offer to switch approach. `supersede` also stays available at any maturity for a genuine reversal you want recorded as a distinct decision.

## Subcommand: adr promote {id} {maturity}

Advance an ADR's maturity along `design → prototyped → implemented` and propagate its consequences to the layers the new maturity reaches.

### Steps

1. Verify the ADR exists and the transition is a **forward** step (`design`→`prototyped`, `prototyped`→`implemented`). Reject skips and downgrades with a warning — a downgrade is not a promote; refine the `Decision` in place with `adr update` instead.
2. Update `**Status:** {maturity}` in the ADR file. For `prototyped`, require a `**Prototype:**` pointer (which repo/prototype validated it, and the evidence); for `implemented`, note where in the codebase it lives.
3. **Propagate / record evidence for the new maturity:**
   - `prototyped` → confirm the design workspace already reflects the decision, then record the `**Prototype:**` pointer to the external functional prototype that validated it (not the console); `implemented` → add the product-codebase reference.
   - For each module listed in "Modules affected", invoke `/inspire_module review {module}` to detect where the ADR's consequences are not yet reflected across the design workspace.
   - Surface the gaps as a list of follow-up actions; offer to orchestrate via the appropriate skills.

## Subcommand: adr supersede {id} {new-id}

Replace an ADR with a new one that changes its decision. Follow after creating the new ADR via `adr create`. Required to change the `Decision` of an `implemented` ADR; available at any maturity when you want the reversal recorded as a distinct decision rather than an in-place edit.

### Steps

1. Verify both ADRs exist (the old one at any non-terminal maturity)
2. Update old ADR: `**Status:** superseded by [[{new-id}]]`
3. Update new ADR's header to include `Supersedes: [[{old-id}]]`
4. Grep `spec/` for references to the old ADR; propose updates to point to the new one
5. Update `spec/adrs/_index.md` (move the old ADR's entry to the superseded section)

## Task tracker format

Tickets live as one file per ticket. The `.md` files are the **only source of truth** — there are no generated indexes or caches.

### Storage layout

- **Open tickets** → `tracker/tickets/TASK-{id}.md`
- **Closed tickets** (`status` ∈ {`Done`, `Cancelled`}) → `tracker/tickets/archive/TASK-{id}.md`

The archive subfolder keeps the active set lean: agents scanning "what's pending" only need to read `tracker/tickets/*.md` (top-level, non-recursive) and don't have to filter out closed work. The Kanban web (`tracker/serve.mjs`) reads both locations so the Done column stays populated.

The `task close` subcommand moves the file as part of the operation. `task show` / `task update` look in `tickets/` first and fall back to `tickets/archive/` so callers don't need to know where a ticket lives.

### Frontmatter schema

```yaml
---
id: TASK-a3k7m2                    # 6 chars base36 random, must match filename
title: Migrate UISpec X to pattern-driven
created: 2026-05-07                # YYYY-MM-DD
updated: 2026-05-07                # YYYY-MM-DD (auto-updated by skill on each change)
reporter: "@oscar"                 # git handle
closed_by: null                    # @handle when status ∈ {Done, Cancelled}
closed_at: null                    # YYYY-MM-DD when status ∈ {Done, Cancelled}
epic: runtime                      # see enum below
size: M                            # S | M | L | XL
importance: High                   # Very Low | Low | Mid | High | Very High
skills: [prototype, ui]            # which layer/scope skills execute the work (see enum below)
status: Open                       # Open | Done | Cancelled
blocked_by: []                     # list of ticket IDs (TASK-xxx, feature IDs, ADRs)
related_to: [TASK-xxx, UMD-DS-04]  # list of IDs
---

## Description
...body markdown libre, recomendado: Description / Acceptance criteria / Notes...
```

### Enums

- **`epic`** (closed): `platform | auth | audit | qa | messaging | datastore | filesystem | runtime | ai-agents | cora | devices | marketplace | cli | cloud | marketplace-portal | portals-sdk | workspace | meta | tooling | docs | skill-feedback`
- **`size`**: `S | M | L | XL`
- **`importance`**: `Very Low | Low | Mid | High | Very High`
- **`status`**: `Open | Done | Cancelled` — Claude either picks up a ticket and finishes it, or doesn't; there is no in-flight state. `Open` = not yet done, `Done` = completed and verified, `Cancelled` = won't do (with reason in body).
- **`skills`** (multi-select, may be empty): `module | feature | object | workspace | ui | prototype | mockdata | back | docs | video` — which layer/scope skills cover the work. A ticket can list multiple (e.g. `[mockdata, prototype]` for a feature that needs new tables + a new screen). Empty `[]` means the work doesn't map cleanly to a layer skill (e.g. tooling, ops, packaging).

### Skill-feedback tickets (convention)

When a skill's usage produces a friction signal worth capturing — an operator pushback, a recurring `AskUserQuestion` pattern that should default, drift from what the skill spec anticipated, ergonomic costs — file it as a standard ticket with this shape:

```yaml
epic: skill-feedback                       # the new epic
skills: [<source-skill>]                   # which skill produced the signal (single-element)
size: S                                    # most are S — cheap to file, scoped per observation
importance: Low                            # default Low; bump when drift is load-bearing
```

**Title format:** `{skill-name}: <short friction observation>` — e.g. `object: AskUserQuestion fires twice on same effect-verb choice when entity is touched twice in a session`.

**Body sections:** `## Observation` (what happened — concrete) · `## Where it surfaced` (subcommand / step / session id if relevant) · `## Suggested follow-up` (what would fix it, if known; OK to leave open).

This is the **interim quick-pass mechanism** for the skill-usage feedback loop (see `tracker/tickets/TASK-9bk2nx.md`). It reuses standard ticket infrastructure — no new tooling, no automated capture. The operator decides when an observation deserves a ticket; skills surface candidates conversationally and offer to file. The fuller mechanism (telemetry / triage cadence / feedback application) lives in TASK-9bk2nx.

### ID scheme

Format: `TASK-` + 6 chars from `[a-z0-9]` (base36 lowercase). Example: `TASK-a3k7m2`.

- **Generation**: random — `Math.floor(Math.random() * 36).toString(36)` × 6.
- **Space**: 36⁶ ≈ 2.18B combinations. Collision probability with 10k tickets ≈ 10⁻⁵.
- **Defense in depth**: before writing a new ticket, verify `tracker/tickets/TASK-{id}.md` doesn't exist. Regenerate on the astronomically improbable collision.
- **Concurrency**: no coordination needed. Parallel branches/sessions create tickets with random IDs and effectively never collide.
- **Stable forever**: cancelled tickets keep their ID (with `status: Cancelled` and reason in body). IDs are never reused.

### Subcommand: task create {title} [--flags]

1. Resolve `@handle` from `git config user.email` (cached per session). Default to `@oscar` if not resolvable.
2. Resolve today's date from CLAUDE.md `currentDate` or `date +%Y-%m-%d`.
3. Generate a random 6-char base36 ID. Verify `tracker/tickets/TASK-{id}.md` doesn't exist; regenerate if it does.
4. Apply flag values for `--epic`, `--size`, `--importance`, `--skills` (comma-separated), `--status`, `--blocked-by`, `--related-to`. Defaults: `epic` required (validated against enum), `size: M`, `importance: Mid`, `skills: []`, `status: Open`, lists empty.
5. Write the file with frontmatter + empty `## Description` body (or content from `--body` if provided).
6. Print the new ID to stdout for confirmation.

### Subcommand: task update TASK-{id} [--flags]

1. Resolve ticket path: try `tracker/tickets/TASK-{id}.md` first, then `tracker/tickets/archive/TASK-{id}.md`. Error if neither exists.
2. Apply flag changes to frontmatter (validate against enums).
3. Set `updated` to today's date.
4. **Status transitions move the file:**
   - If new `status` ∈ {`Done`, `Cancelled`} and the file is currently in `tickets/` → write to `tickets/archive/TASK-{id}.md` and remove the original. Fill `closed_by` (current handle) and `closed_at` (today).
   - If transitioning back to `Open` and the file is currently in `tickets/archive/` → write to `tickets/TASK-{id}.md` and remove the archived copy. Clear `closed_by` / `closed_at`.
   - Otherwise, write in place.
5. Show diff before saving.

### Subcommand: task close TASK-{id} [--cancelled --reason "..."]

Shortcut for `task update` that transitions an open ticket to a closed status and archives it:
- Default: `status: Done`.
- With `--cancelled`: `status: Cancelled`. If `--reason` given, append a `## Cancellation reason` section to body (or update existing).
- Sets `closed_by`, `closed_at`, `updated` to today.
- **Moves the file** from `tracker/tickets/TASK-{id}.md` to `tracker/tickets/archive/TASK-{id}.md` as part of the same operation.

### Subcommand: task list [--filter]

1. Scan `tracker/tickets/*.md` (top-level, non-recursive — does NOT include `archive/`). Parse frontmatter.
2. With `--include-archived` (or `--all`), also scan `tracker/tickets/archive/*.md` and merge.
3. Apply filters: `--status`, `--epic`, `--size`, `--importance`, `--reporter`, `--skill` (matches if ticket's `skills` list contains the value), `--blocked` (only blocked tickets), `--open-only` (alias for `--status Open` — redundant with the default scope but accepted for clarity).
4. Print as a compact table to stdout: `id | status | epic | size | importance | skills | title`.
5. Read-only. Never modifies files.

### Subcommand: task show TASK-{id}

1. Read the file from `tracker/tickets/TASK-{id}.md`; if absent, fall back to `tracker/tickets/archive/TASK-{id}.md`.
2. Print frontmatter + body to stdout.
3. Read-only.

### Rules

1. **One file per ticket.** Filename = `TASK-{id}.md`. The `id` field in frontmatter must match the filename.
2. **IDs never reused.** Cancelled tickets stay with `status: Cancelled`. Don't delete files — archive them.
3. **Open vs archived location is derived from `status`.** Open tickets live at `tracker/tickets/`; closed tickets (Done/Cancelled) at `tracker/tickets/archive/`. The skill is responsible for keeping file location consistent with the `status` field on every transition.
4. **`updated` is auto-managed by the skill.** Don't edit it by hand.
5. **`closed_by`/`closed_at` only when status ∈ {Done, Cancelled}.** Skill enforces consistency.
6. **Body markdown is free.** No required sections, but Description / Acceptance criteria / Notes is the suggested pattern.
7. **Concurrent edits are safe.** Random IDs make collisions effectively impossible. No locking, no merge conflicts on filenames.
8. **Server is read-only.** `tracker/serve.mjs` never writes. All mutations go through the skill (or direct `.md` edits, but the skill is preferred for consistency). The server scans both `tickets/` and `tickets/archive/`.

## Subcommand: structure

Validate the vault structure at the top level (not module-scoped).

### Checks

1. **CLAUDE.md** is present at workspace root and has the skills table
2. **Top-level indexes:**
   - `spec/pdd/_index.md` lists every core module + satellite
   - `spec/adrs/_index.md` lists every ADR
   - Each module folder has `_index.md`
3. **Task tracker:**
   - `tracker/tickets/` exists with valid `.md` files at top level (open tickets) and under `tracker/tickets/archive/` (closed). Frontmatter parses, enums match, ID format `TASK-[a-z0-9]{6}`.
   - `id` in frontmatter matches filename
   - No duplicate IDs across `tickets/` and `tickets/archive/` (defense in depth)
   - **Location ↔ status invariant:** every ticket in `tickets/*.md` (top-level) has `status: Open`; every ticket in `tickets/archive/*.md` has `status` ∈ {`Done`, `Cancelled`}. Mismatches are violations.
   - `tracker/serve.mjs` and `tracker/web/index.html` present
   - References in `blocked_by` / `related_to` to other `TASK-*` IDs resolve (warning if not — search both `tickets/` and `tickets/archive/`)
4. **No orphan files:**
   - No stale `.md` at `spec/` root (except `CONTRIBUTING.md` if present)
   - No legacy paths (e.g., `pdd/openbims-portal/`, `.claude/PENDING.md`)
5. **Sync scripts** in `code/*/scripts/` point to current paths

### Output

```markdown
# Vault Structure | {date}

## Top-level indexes
- spec/pdd/_index.md: {ok | N issues}
- spec/adrs/_index.md: {ok | N issues}

## Module folders
- Core modules: {N}/12 with _index.md
- Satellites: {N}/{total}

## Task tracker
- tracker/tickets/: {N} open
- tracker/tickets/archive/: {N} closed ({Done: N, Cancelled: N})
- tracker/serve.mjs: {present | missing}

## Issues
- [{severity}] {description}

## OK
```

## Rules

1. **`review` is read-only.** Everything it finds, it suggests. It does not edit files.
2. **ADR maturity is explicit.** Advancing `design → prototyped → implemented` requires `adr promote`; it is not automatic. `create` defaults to `design`.
3. **Only `implemented` ADRs are immutable in content.** Supersede to change their `Decision`; `design` / `prototyped` ADRs are refined in place with `adr update`.
4. **Propagate to the maturity's reach.** Design-workspace coherence (PDD + UISpec + console prototype + mock + manual) is required at every maturity; `prototyped` adds a pointer to an external functional prototype, `implemented` a codebase reference. The skill surfaces gaps within that reach.
5. **Grep references on rename/supersede.** Always scan the vault for references when renaming an ADR or changing its ID.
6. **Consult the task tracker.** Known items live in `tracker/tickets/` (use `task list` or open the Kanban via `node tracker/serve.mjs`). Don't re-report them as new findings.
7. **No historical language in ADRs.** ADRs describe the decision context at the time it was made. Don't narrate migration history.
8. **Immutability at `implemented`.** To change an implemented decision, supersede with a new ADR; below that maturity, refine in place with `adr update`.
