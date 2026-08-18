# Feature — scan
> Part of [inspire-feature](../SKILL.md). Read when the entry's index routes here.

## Subcommand: scan

The feature-level entry point for SDD-layer work. Same three phases as
[`/inspire_module scan`](../../inspire-module/references/module-scan.md), scoped to
one feature or one module's features. The worktree check, the plural→singular
canonicalization on action ids, the existence check at
`inspire_kb/04_domain/{module}/{entity}/{action}.md`, the one-question-at-a-time
dialogue, and the chained-authoring handoff to `/inspire_domain define` are that
file's Phase 1–3 protocol, unchanged for a feature — read it there rather than
here.

The one candidate-surfacing delta: scan reads the feature file and infers the
actions that would realize it (most features map to 1–3), rather than reading
the actions a module hub and its feature files already declare.

Scan is read-only with respect to `inspire_kb/04_domain/`; authoring lives in
`/inspire_domain`. **Batch mode** (`scan {module}`) expands this over every
feature file in `inspire_kb/03_features/{module}/`.

### Phase 4 — Audit report

After the dialogue, scan surfaces per-feature audit findings: features with no
realizing action, partial realization, and lifecycle mismatch (feature marked
implemented but realizing actions still `lifecycle: draft`). Render via
[`_references/findings-format.md`](../../_references/findings-format.md).
