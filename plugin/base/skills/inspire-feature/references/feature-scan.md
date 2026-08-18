# Feature — scan
> Part of [inspire-feature](../SKILL.md). Read when the entry's index routes here.

## Subcommand: scan

The feature-level entry point for SDD-layer work. Same three phases as
[`/inspire_module scan`](../../inspire-module/references/module-scan.md), scoped to one
feature or one module's features:

1. **Environment setup** — confirm a clean worktree on the right branch, or offer
   to bootstrap one (direct `git worktree add`; do NOT defer to a third-party
   worktree skill — the `inspire-*` family must stay portable).
2. **Candidate surfacing + narrowing** — read the feature file, infer the actions
   that would realize it (most features map to 1–3), apply plural→singular
   canonicalization on action ids silently, check whether each already exists at
   `inspire_kb/04_domain/{module}/{entity}/{action}.md`, and dialogue with the
   operator to pick a set. One focused question at a time; follow the
   conversational conventions of [`/inspire_domain`](../../inspire-domain/SKILL.md).
3. **Chained authoring** (only on an explicit "start" signal) — create one
   `TaskCreate` per chosen action, mark the first `in_progress`, and invoke
   `/inspire_domain define {id}` via the Skill tool; `inspire-domain` runs its
   socratic interview and may co-evolve the action + entity documents in one flow.

Scan is read-only with respect to `inspire_kb/04_domain/`; authoring lives in
`/inspire_domain`. Pure exploration leaves no tasks created. **Batch mode**
(`scan {module}`) expands this over every feature file in
`inspire_kb/03_features/{module}/`.

### Phase 4 — Audit report

After the dialogue, scan surfaces per-feature audit findings: features with no
realizing action, partial realization, and lifecycle mismatch (feature marked
implemented but realizing actions still `lifecycle: draft`). Render via
[`_references/findings-format.md`](../../_references/findings-format.md).
