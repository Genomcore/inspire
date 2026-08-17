# Subcommand: review

Read-only quality check. Runs the quality_lib rules against the scope and surfaces findings. Never auto-fixes.

## Flow

1. Invoke `.inspire/bin/review.sh` for the scope.
2. Collect findings from stderr (JSON Lines format — see [`findings-format.md`](../../../_references/findings-format.md)).
3. Render each finding as a markdown sub-section using the shared format: heading `### {severity} · {rule} — {target}`, then **Issue** and **Suggested follow-up**.
4. Summary at the top: counts by severity, pass/fail.

`review` suggests a follow-up action (`/inspire_domain update`, `promote`, etc.) per finding but does not apply it.

## The quality gate (per D24)

The gate composes rule families across three severity tiers, plus the style checks below them. `review` runs every check regardless of the current lifecycle; severity scales by tier and by the object's own state.

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

**Tier 3 — Lifecycle-progressive (draft → warning, accepted / stable → error, superseded → warning):**

| Rule | What it catches |
|---|---|
| `field-coverage` | Entity Fields row declared but no action touches the field |
| `rationale-wikilink` | Entity `## Rationale` (or action `## Purpose` ∪ `## Behavior`) has no `[[wikilink]]` back-source |
| `wikilinks-resolve` | A `[[wikilink]]` in body does not resolve to an existing file |

**Style — the mechanical subset of the writing contract:**

| Rule | What it catches |
|---|---|
| `prose-style` R2 · R4 · R5 · R6 | A sentence over 25 words; a synonym the glossary rejects; a paragraph over 6 sentences; one of the closed historical-language tokens. Same ramp as tier 3 — these read the object's own `lifecycle:`. |
| `prose-style` R1 · R3 | Passive voice; a run of four or more stacked nouns. Heuristics: **warning at every lifecycle, never ramping.** |

The checks are English-only in 0.7. A project whose `output_language` is not
`en` gets a single info-level note and no findings — report that note as it
stands, and do not present it as a clean bill of health: the contract in
[`writing-style.md`](../../../_references/writing-style.md) still binds as
authoring judgment.

The full per-state gate table is in [`lifecycle-rules.md`](../../../_references/lifecycle-rules.md). Implementation in `.inspire/bin/*.sh` (see [`.inspire/bin/README.md`](../../../../bin/README.md) for the script catalog).
