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
- **Vault structure** — module hubs and ADR files, folder conventions, and the
  tracker's on-disk invariants.

It does **not** own the artifacts it validates the coherence of: **ADR lifecycle**
is [`/inspire_adr`](../inspire-adr/SKILL.md) and the **task tracker** is
[`/inspire_task`](../inspire-task/SKILL.md). This skill reads ADRs and tickets to
judge coherence; it never authors them.

When the project declares a **surface roster** (`inspire_kb/00_bootstrap/surfaces.md`),
several checks in `review` and `structure` read against it. The rules — the three kinds,
what `surfaces:` means on an artifact, and the two shapes the screens tree takes — are
defined once in [`_references/surface-scope.md`](../_references/surface-scope.md); read
it before judging anything surface-scoped. A project with no roster is a **suite of
one**, and every check reads exactly as it did before surfaces existed.

## Invocation

- `/inspire_workspace review` — full vault review
- `/inspire_workspace review {module1} {module2}` — scoped to selected modules + cross-module checks
- `/inspire_workspace structure` — validate module hubs, ADR files, task tracker, vault conventions

## Subcommands in `references/`

Each subcommand's core procedure lives in a reference file. **Before executing
any subcommand, read every reference file its index row names** — the table
below is an index, not the flow.

| Subcommand | What its reference holds |
|---|---|
| [`review`](references/workspace-review.md) | Phases 3–6 + Signals — the cross-cutting checks; the Execution mode, Phases 1–2, the Output format skeleton and the `### Review rules` stay in this file; Phase 2 additionally reads [`inspire-module/references/module-review.md`](../inspire-module/references/module-review.md) |
| [`structure`](references/workspace-structure.md) | The full top-level vault checks + their output skeleton |

## Subcommand: review (global)

**REQUIRED** before any PR that modifies files in `inspire_kb/`. Orchestrates a
full consistency review across all affected modules and the vault structure.

### Execution mode

The **checks, severity model, and output are identical** in both modes — only the
scheduling differs.

- **Sequential (default).** Execute the phases top-to-bottom in this agent — Phases
  1–2 below, then Phases 3–6 + Signals in
  [`references/workspace-review.md`](references/workspace-review.md).
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

- If modules are specified, use those. Otherwise, enumerate module hubs:
  `inspire_kb/02_modules/*.md` excluding `_*.md` and `README.md` — the glob is
  the index.
- For each module in scope, delegate to `/inspire_module review {module}`.

### Phase 2 — Module reviews

For each module in scope, the module review performs the checks in
[`inspire-module/references/module-review.md`](../inspire-module/references/module-review.md)
— referenced, never restated.

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
   are flagged `(tracked: TASK-{id})`. Use `/inspire_task list`.
10. **Required follow-up skills.** When flagging drift, name the mandatory fix skill:
   - Prototype drift → `/inspire_prototype`
   - screen spec drift → `/inspire_screens`
   - Feature drift → `/inspire_module update` or `/inspire_feature update`
   - ADR misalignment → `/inspire_adr update`
   - Screens tree out of shape, or an unresolved `surfaces:` id → `/inspire_surface review`

## Subcommand: structure

The full procedure — the top-level vault checks and their output skeleton —
lives in [`references/workspace-structure.md`](references/workspace-structure.md).

## Rules

> **Output language.** Write review reports and findings in the project's declared
> `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in; machine-read tokens (frontmatter
> keys/values, wikilink slugs, filenames) stay verbatim.

> **Writing contract.** Review reports and findings follow
> [`_references/writing-style.md`](../_references/writing-style.md).

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire_lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

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
