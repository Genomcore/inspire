# Subcommand: review

Read-only quality check. Runs the quality_lib rules against the scope and surfaces findings. Never auto-fixes.

## Flow

1. Invoke `.claude/bin/review.sh` for the scope.
2. Collect findings from stderr (JSON Lines format — see [`findings-format.md`](../../../_references/findings-format.md)).
3. Render each finding as a markdown sub-section using the shared format: heading `### {severity} · {rule} — {target}`, then **Issue** and **Suggested follow-up**.
4. Summary at the top: counts by severity, pass/fail.

`review` suggests a follow-up action (`/inspire_object update`, `promote`, etc.) per finding but does not apply it.

## The quality gate (per D24)

The gate composes 10 rule families across three severity tiers. `review` runs every check regardless of the current lifecycle; severity scales by tier and by the object's own state.

**Tier 1 — Mechanical blockers (always error, any lifecycle):**

| Rule | What it catches |
|---|---|
| `lifecycle-valid` | Missing or non-enum `lifecycle:` frontmatter value |
| `requires-resolves` | `requires:` entries that don't resolve to existing action descriptors |
| `superseded-by-resolves` | `superseded_by:` set but pointing to a non-existent target |
| `acyclic-deps` | Self-loops and cycles in the action→action `requires` graph |

**Tier 2 — Coherence blockers (error from draft+):**

| Rule | What it catches |
|---|---|
| `sections-present` | Missing or empty mandatory body sections (actions: 6 sections; entities: 4 sections) |
| `no-todos` | `TODO` / `FIXME` / `XXX` / `HACK` markers in body (D19: files state present truth only) |
| `action-fields-in-entity` | Action touches a field the entity doc's `## Fields` table does not declare |
| `entity-coherence` | field-conflict (error), field-unsourced (error), field-orphan-write (warning) across actions sharing an entity |
| `stable-blockers` | `stable` actions whose `requires:` targets are not yet stable |
| `touched-entity-lifecycle` | `stable` action touching an entity below `accepted` |

**Tier 3 — Lifecycle-progressive (warning at draft, error at accepted+):**

| Rule | What it catches |
|---|---|
| `field-coverage` | Entity Fields row declared but no action touches the field |
| `rationale-wikilink` | Entity `## Rationale` (or action `## Purpose` ∪ `## Behavior`) has no `[[wikilink]]` back-source |
| `wikilinks-resolve` | A `[[wikilink]]` in body does not resolve to an existing file |

The full per-state gate table is in [`lifecycle-rules.md`](../../../_references/lifecycle-rules.md). Implementation in `.claude/bin/*.sh` (see [`.claude/bin/README.md`](../../../../bin/README.md) for the script catalog).
