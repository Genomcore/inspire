---
name: inspire-workspace
description: "Workspace-level validation: the global pre-PR review (orchestrating module + cross-module checks) and vault-structure validation. Use for the required pre-merge gate and top-level structure checks. ADR lifecycle lives in /inspire_adr; the task tracker in /inspire_task."
---

# /inspire_workspace — Workspace-level Operations

## Scope

This skill owns **workspace-scoped validation** — the cross-cutting checks that
don't belong to a single module or feature:

- **Global review** — the pre-merge gate, orchestrating module-level and
  cross-module checks.
- **Vault structure** — top-level indexes (`inspire_kb/02_modules/_index.md`,
  `inspire_kb/01_adr/_index.md`), folder conventions, and the tracker's on-disk
  invariants.

It does **not** own the artifacts it validates the coherence of: **ADR lifecycle**
is [`/inspire_adr`](../inspire-adr/SKILL.md) and the **task tracker** is
[`/inspire_task`](../inspire-task/SKILL.md). This skill reads ADRs and tickets to
judge coherence; it never authors them.

When the project declares a **surface roster** (`inspire_kb/00_bootstrap/surfaces.md`),
several checks below read against it. The rules — the three kinds, what `surfaces:`
means on an artifact, and the two shapes the screens tree takes — are defined once in
[`_references/surface-scope.md`](../_references/surface-scope.md); read it before
judging anything surface-scoped. A project with no roster is a **suite of one**, and
every check below reads exactly as it did before surfaces existed.

## Invocation

- `/inspire_workspace review` — full vault review
- `/inspire_workspace review {module1} {module2}` — scoped to selected modules + cross-module checks
- `/inspire_workspace structure` — validate top-level indexes, task tracker, vault conventions

## Subcommand: review (global)

**REQUIRED** before any PR that modifies files in `inspire_kb/`. Orchestrates a
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
  `inspire_kb/02_modules/_index.md`.
- For each module in scope, delegate to `/inspire_module review {module}`.

### Phase 2 — Module reviews

For each module in scope, the module review performs:
- Features structure (pure `_index.md`, use-case files, index completeness)
- screen spec structure (pattern/component compliance)
- Quality checks (no historical language, IDs correct, wikilinks resolve)
- Cross-layer coverage (features ↔ screen spec ↔ prototype ↔ specs)
- Drift consolidation and overengineering detection

### Phase 3 — Cross-module consistency

- **Dependency validation:** feature IDs referenced as dependencies in one module
  exist in the target.
- **ADR references:** all `[[adr-xxx]]` wikilinks resolve to files in
  `inspire_kb/01_adr/`.
- **ADR propagation alignment:** at *every* maturity, an ADR's consequences must
  cohere across the **in-repo design workspace** (features + screen spec + horizontal
  prototype + specs) — a contradiction there is critical. Higher maturities add
  *external* evidence checked only by pointer, never by inspecting the external
  artifact: `prototyped` needs a `**Prototype:**` pointer; `implemented` a codebase
  reference. A `design` ADR merely lacking external validation is NOT a finding; a
  `design` ADR that contradicts the horizontal prototype IS.
- **Surface references:** every `surfaces:` value in the vault resolves to an id in
  the roster, or to `all`. An unknown id is critical — it scopes the artifact to
  nothing. An **absent** field is never a finding: it means suite-wide. With no roster
  the check is vacuous, since a suite of one has no ids to resolve against.
  (`/inspire_surface review` runs the same check roster-side; here it is part of the
  pre-merge gate, over every artifact in scope.)
- **No undocumented circular dependencies.**

### Phase 4 — Vault structure

**Features tree:**
- Repo structure matches CLAUDE.md.
- No scripts, `.py`, `.xlsx`, `.deprecated`, or `.DS_Store` files in `inspire_kb/`.
- Every module has a hub in `inspire_kb/02_modules/`; its per-layer subfolders
  (`03_features`, `05_screens`, `04_domain`) stay in sync with it. Under a
  surface-first screens tree a module's screens live in one or more
  `{surface}/{module}/` directories: it owes at least one, never one per surface —
  a module realized on a single surface is normal.
- `inspire_kb/01_adr/_index.md` lists all ADR files (no orphans, no phantoms).
- `inspire_kb/02_modules/_index.md` lists all modules.

**screen spec tree:**
- `inspire_kb/05_screens/design-system.md` exists.
- `inspire_kb/05_screens/patterns/` and `components/` exist with `_index.md` + files,
  at top level — beside any surface trees, never inside one.
- **The tree is in the shape the roster implies.** Both shapes are legitimate: flat
  `{module}/` with no roster or a single `kind: ui` surface, surface-first
  `{surface}/{module}/` (plus `shared/{module}/`) from two UI surfaces on. Derive
  which applies from [`_references/surface-scope.md`](../_references/surface-scope.md)
  — never from what the tree used to be. Under 2+ UI surfaces, a flat `{module}/`
  directory is a **pre-split leftover** in either of its instances: the whole tree
  still flat, or one flat directory sitting beside surface trees. Name the instance
  and hand the roster-side diagnosis and the corrective sweep to
  [`/inspire_surface review`](../inspire-surface/SKILL.md) (its check 5); this phase
  reports, it does not re-derive the fix. The check lives here because this is the
  only pass that walks the whole screens tree — a module review sees one module's
  directory.
- Every pattern/component referenced by a screen exists; no orphans (on disk, not
  referenced) — orphan counting respects blast radius, see Phase 6.

### Phase 5 — Prototype component adoption

- Enumerate the shared components catalogued in `inspire_kb/05_screens/components/`.
- For each, count adoption in the horizontal prototype (`/prototype`): pages using
  the canonical component vs pages still inlining an equivalent.
- **From two UI surfaces on, count per shell.** The prototype holds one shell per UI
  surface, so report one line per shell rather than a single suite-wide ratio: a
  component adopted throughout one shell and absent from another is a different
  problem from a migration progressing evenly everywhere, and a pooled ratio reads the
  same for both. A
  component whose `surfaces:` list narrows it is counted only against the shells in
  that blast radius.
- Report consolidated drift. High drift is `important` (not critical) — migration
  progresses over time.

### Phase 6 — Catalog coherence

- Patterns catalog: for each pattern file, count references from screens.
- Components catalog: for each component file, count usages in the prototype.
- Flag patterns/components with 0 references (unused or not migrated yet).
- **Judge an entry inside its own blast radius.** A catalog entry carrying `surfaces:`
  is counted only against the surfaces it names — a `surfaces: [admin]` pattern used
  across the admin shell and nowhere else is fully adopted, not an orphan. Zero
  references *within its blast radius* is the finding. An absent field still means
  suite-wide, so an unscoped entry is judged as before.
- Flag screens claiming a pattern/component that doesn't exist.
- **Design-system variance signal.** Report how many per-surface variant sections
  `05_screens/design-system.md` carries and how much of the file they occupy. Those
  sections are defined by
  [`/inspire_bootstrap design-system`](../inspire-bootstrap/SKILL.md), which allows
  them deliberately and expects them to stay rare; a count that keeps climbing is the
  early shape of a design system splitting in place, which is why it is worth
  counting. **Informational only** — it carries no severity, is reported even when
  nothing is wrong, and never blocks the gate.

### Signals

Alongside the findings above, this review runs `.inspire/bin/trust.sh report` and pastes
its output verbatim — the artifact-trust groups, machine-computed; see
[trust-stamps](../_references/trust-stamps.md#report) for what each group means. The
design-system variance count (Phase 6) is reported here too, not under Catalog Coherence.

### Output format

```markdown
# Global Review | {date}

## Scope
- Modules reviewed: {list}

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
- {Component} — {shell}: {adopted}/{total} pages   (one line per shell, from 2+ UI surfaces)
## Catalog Coherence
- Patterns: {total} defined, {used}, {orphan}
- Components: {total} defined, {used}, {orphan}
- Design system variance: reported under Signals

## Signals
{`.inspire/bin/trust.sh report` output, verbatim}
- Design system: {N} per-surface variant section(s), {L} lines

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
7. **Pending drift is not failure.** Prototype drift and pending component adoption
   are `important`, not `critical`, unless they contradict an ADR within its
   maturity's reach. The design-system variance count is weaker still: a signal, not
   a finding — reported every run, never blocking.
8. **Signals are measurements, not findings.** No fix routing beyond the owning
   skill, severity never above important, they re-appear as long as true; never
   file tickets from signals; never block the pre-PR gate on them.
9. **Consult the task tracker.** Known items in `inspire_kb/99_tracker/tickets/`
   are flagged `(tracked: TASK-{id})`. Use `/inspire_task list` or open the Kanban
   via `node inspire_kb/99_tracker/serve.mjs`.
10. **Required follow-up skills.** When flagging drift, name the mandatory fix skill:
   - Prototype drift → `/inspire_prototype`
   - screen spec drift → `/inspire_screens`
   - Feature drift → `/inspire_module update` or `/inspire_feature update`
   - ADR misalignment → `/inspire_adr update`
   - Screens tree out of shape, or an unresolved `surfaces:` id → `/inspire_surface review`

## Subcommand: structure

Validate the vault structure at the top level (not module-scoped).

### Checks

1. **CLAUDE.md** is present at the workspace root.
2. **Top-level indexes:**
   - `inspire_kb/02_modules/_index.md` lists every module.
   - `inspire_kb/01_adr/_index.md` lists every ADR.
   - Each module has a hub `02_modules/{module}.md`.
3. **Task tracker:**
   - `inspire_kb/99_tracker/tickets/` has valid `.md` files at top level (open)
     and under `archive/` (closed). Frontmatter parses, enums match, ID format
     `TASK-[a-z0-9]{6}`.
   - `id` matches filename; no duplicate IDs across `tickets/` and `archive/`.
   - **Location ↔ status invariant:** every top-level ticket is `Open`; every
     archived ticket is `Done`/`Cancelled`.
   - `inspire_kb/99_tracker/serve.mjs` present.
   - `blocked_by` / `related_to` references to other `TASK-*` IDs resolve (warning
     if not).
4. **No orphan files:** no stale `.md` at `inspire_kb/` root (except
   `CONTRIBUTING.md` if present); no legacy paths.

### Output

```markdown
# Vault Structure | {date}

## Top-level indexes
- inspire_kb/02_modules/_index.md: {ok | N issues}
- inspire_kb/01_adr/_index.md: {ok | N issues}

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

> **Output language.** Write review reports and findings in the project's declared
> `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in; machine-read tokens (frontmatter
> keys/values, wikilink slugs, filenames) stay verbatim.

1. **`review` and `structure` are read-only.** They suggest and flag; they never
   edit files or invoke a fix-skill.
2. **ADR propagation is judged, not authored.** Review checks that an ADR's
   consequences cohere within its maturity's reach (design workspace at every
   maturity; external pointers at higher ones) — authoring/advancing ADRs is
   `/inspire_adr`.
3. **Consult the task tracker.** Known items live in
   `inspire_kb/99_tracker/tickets/` (`/inspire_task list`); don't re-report them as
   new findings.
4. **Git discipline is shared.** Branch/commit/PR conventions, merge-conflict
   auditing, and the git safety protocol live in
   [`_references/git-conventions.md`](../_references/git-conventions.md) (sensible
   defaults; the project's `CLAUDE.md` overrides). Follow it whenever the operator
   asks for a branch, commit, or PR — and never commit/push on your own initiative.

## Related skills

- `/inspire_adr` — ADR lifecycle (create / update / promote / supersede). Review
  judges whether ADR consequences propagated; `/inspire_adr` authors them.
- `/inspire_task` — the task tracker. `structure` validates its on-disk invariants;
  `/inspire_task` operates the tickets.
- `/inspire_module`, `/inspire_feature` — the module/feature reviews this
  orchestrates and delegates deep dives to.
- `/inspire_surface` — owns the roster and is the diagnostic for its coherence.
  Review flags a screens tree out of shape and `surfaces:` values that don't resolve;
  diagnosing the roster and running the corrective sweep are that skill's.
