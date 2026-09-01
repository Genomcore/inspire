# Subcommand: review

Read-only quality check. Runs the quality_lib rules against the scope and surfaces findings. Never auto-fixes.

## Flow

1. Invoke `.inspire/bin/review.sh` for the scope.
2. Collect findings from stderr (JSON Lines format — see [`findings-format.md`](../../../_references/findings-format.md)).
3. Render each finding as a markdown sub-section using the shared format: heading `### {severity} · {rule} — {target}`, then **Issue** and **Suggested follow-up**.
4. Summary at the top: counts by severity, pass/fail.

`review` suggests a follow-up action (`/inspire-domain update`, `promote`, etc.) per finding but does not apply it.

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
| `sections-present` | Missing or empty mandatory body sections. Actions: the pre-0.8 core six (`## Purpose` · `## Inputs` · `## Outputs` · `## Entities` · `## Behavior` · `## Errors`); entities: four. Section ORDER is checked against the full canonical eight, so a misplaced `## Preconditions` or `## Postconditions` is caught here while their *presence* is `keys-present`'s, where in 0.8 it is a warning at every lifecycle rather than an error from `accepted` |
| `no-todos` | `TODO` / `FIXME` / `XXX` / `HACK` markers in body (D19: files state present truth only) |
| `action-fields-in-entity` | Action touches a field the entity doc's `## Fields` table does not declare |
| `entity-coherence` | field-conflict (error), field-unsourced (error), field-orphan-write (warning) across actions sharing an entity |
| `stable-blockers` | `stable` actions whose `requires:` targets are not yet stable |
| `touched-entity-lifecycle` | `stable` action touching an entity below `accepted` |

**Tier 3 — Lifecycle-progressive (draft → warning, accepted / stable → error, superseded → warning):**

| Rule | What it catches |
|---|---|
| `keys-present` | An entry that cannot be named: prose invariants instead of keyed `I{n}`; an unkeyed `## Behavior` or `## Main flow` step; an absent or empty `## Preconditions` / `## Postconditions`; a head outside its closed vocabulary; a key used twice. Finding messages carry the old-shape class id (`OS-A1`, `OS-E3`, …) from [`keyed-heads.md`](../../../_references/keyed-heads.md) |
| `constraints-mechanics` | A `Constraints:` line that is malformed, carries a word outside the closed V1 vocabulary, uses one at the wrong arity, or sits somewhere other than its H3's first content line (`OS-E8` — the line is read and checked wherever it sits, so only its placement is the finding); an entity whose `id` carries no Constraints line (the pre-keying marker) or no `id` row at all; `nonnull` on an input line, where the `Required` column already owns required-ness |
| `head-referents` | A head naming something that is not there: a written `unique` field with no matching `unique(...)` error head; an invariant head naming a field absent from `## Fields`; a `P`/`Q` head naming an untouched entity; `returns(...)` naming a missing output; an unresolvable `references(...)` |
| `field-coverage` | Entity Fields row declared but no action touches the field |
| `rationale-wikilink` | Entity `## Rationale` (or action `## Purpose` ∪ `## Behavior`) has no `[[wikilink]]` back-source |
| `wikilinks-resolve` | A `[[wikilink]]` in body does not resolve to an existing file |

`constraints-mechanics` also emits the one **permanent** flat-warning finding in
this family, `W-1`: a constraint still narrated in a `Notes` or `Description`
cell after its machine-readable form moved to a `Constraints:` line. It scans
those table cells only, never per-field H3 prose. It never ramps and never
blocks — recognising a constraint word inside prose is a heuristic, and a
heuristic does not get to fail a gate.

**Five classes in the three keyed-head rules do not ramp in 0.8** and sit
outside the table above: `OS-A1` (no `B{n}` on the first `## Behavior` step),
`OS-A3` / `OS-A4` (no `## Preconditions` / `## Postconditions`), `OS-E1` (no
`Constraints:` line on `id`) and `OS-E3` (prose or unkeyed `## Invariants`).
These are the *presence* classes — the shape an upgrade inherits, indistinguishable
from a new artifact someone forgot to key — so they are **warnings at every
lifecycle state**, at pre-commit, pre-PR and `promote` alike, and their messages
end `— derive refuses old-shape artifacts`. Everything else these rules report
ramps exactly as the table says. The five ramp too, in the release after 0.8.

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

The full per-state gate table is in [`lifecycle-rules.md`](../../../_references/lifecycle-rules.md). Implementation in `.inspire/bin/*.sh` (see [`.inspire/bin/README.md`](../../../../../.inspire/bin/README.md) for the script catalog).
