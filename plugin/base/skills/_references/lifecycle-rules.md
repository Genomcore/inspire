# Lifecycle rules (shared reference)

Every SDD object — **action descriptor** (`inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md`) and **entity document** (`inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md`) alike — carries a `lifecycle:` field in its frontmatter. The lifecycle controls which quality_lib rules apply and what transitions the agent will offer. The two object kinds share the same 4-state enum and the same state machine.

## The 4-state enum

| State | Meaning |
|---|---|
| `draft` | In design. Free authoring; very few invariants enforced. |
| `accepted` | Design closed. The contract is being implemented; for entities, the field shape is locked. |
| `stable` | Implementation locked. For actions, all `requires:` deps and all touched entities must be at least accepted (entities must themselves be ≥ accepted; deps must be stable). Treated as a release contract. |
| `superseded` | Escape hatch. The object exists for backward reference but is no longer authoritative; carries a `superseded_by:` pointer. |

## State diagram

```
                          ┌────────────────┐
                          │   superseded   │ ← reachable from ANY state
                          └────────────────┘
                              ▲ ▲ ▲
                              │ │ │
       ┌────────┐     ┌────────────┐     ┌────────┐
       │ draft  │ ──► │  accepted  │ ──► │ stable │
       └────────┘     └────────────┘     └────────┘
            ▲              ▲                  │
            └──────────────┴──────────────────┘
                  regression permitted
```

Forward progression: `draft → accepted → stable`. Regression (`stable → accepted`, `accepted → draft`) is permitted when a downstream constraint forces it — `/inspire_domain promote` walks both directions, just confirms more carefully on regressions.

`superseded` is the escape hatch. An action in any state can be marked superseded; the descriptor stays in the tree, carries `superseded_by: "[[module::entity::new-action]]"`, and is dropped from the in-scope `requires` graph (other actions that listed it must be updated separately — `/inspire_domain graph` flags affected callers).

## Per-state rule gates

The quality gate (D24) — rule families across three severity tiers, plus the style checks below them, running at every commit:

### Tier 1 — Mechanical blockers (always error)

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `lifecycle-valid` (frontmatter `lifecycle:` present + enum-valid) | error | error | error | error |
| `requires-resolves` (`requires:` resolves to existing action) | error | error | error | error |
| `superseded-by-resolves` (`superseded_by:` resolves when set) | error | error | error | error |
| `acyclic-deps` (no self-loop, no cycle) | error | error | error | error |

### Tier 2 — Coherence blockers (error from draft+, except where a row says otherwise)

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `sections-present` (mandatory body sections present + non-empty; `## Touched by` presence-only) | error | error | error | error |
| `sections-present` (canonical section ORDER, `04_domain` only) | warning | error | error | warning |
| `no-todos` (no TODO/FIXME markers — D19) | error | error | error | error |
| `action-fields-in-entity` (action touch declarations match entity Fields table) | error | error | error | error |
| `entity-coherence` (field-conflict, unsourced — error; orphan-write — warning) | enforced | enforced | enforced | enforced |
| `stable-blockers` (`requires:` deps must be stable) | exempt | exempt | error | exempt |
| `touched-entity-lifecycle` (touched entities must be ≥ accepted) | exempt | exempt | error | exempt |

`sections-present` is the one rule that splits its severity by **layer**, because
this table's columns only exist in `04_domain`: a use-case file, an ADR and a
screen file carry no `lifecycle:` at all, so nothing there can ramp. The rule
checks their shapes too — sections, the `AC-N` id format, `### Breaking changes`,
the screen's required parts — and every finding it makes outside `04_domain` is a
**warning**, at every moment of that artifact's life. The table above is the
`04_domain` half. Its second row is the exception within the exception: the order
check *does* ramp, because what a draft may still be reshaping an accepted or
stable object has fixed.

Some shapes are deliberately presence-only rather than non-empty: an entity's
`## Touched by` (consolidation owns its body, and a zero-toucher entity
legitimately has none — `field-coverage` already reports that fact at tier 3),
and an ADR's `### Breaking changes` (an ADR that breaks nothing still says so).

### Tier 3 — Lifecycle-progressive (draft → warning, accepted / stable → error, superseded → warning)

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `field-coverage` (every entity Fields row touched by ≥1 action) | warning | error | error | warning |
| `rationale-wikilink` (≥1 wikilink in Rationale / Purpose / Behavior) | warning | error | error | warning |
| `wikilinks-resolve` (every `[[wikilink]]` resolves to a file) | warning | error | error | warning |

The tier-3 rules ramp severity by the *current object's* lifecycle, not by the lifecycle of the targets they reference. A draft entity missing rationale wikilinks emits a warning; the same entity at `accepted` emits an error and blocks promotion. `superseded` de-escalates back to warning: the object is history, kept for the pointer to what replaced it, and no longer worth blocking a commit over.

### Style — the mechanical subset of the writing contract

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `prose-style` R2 sentence cap · R4 glossary synonyms · R5 paragraph length · R6 historical language | warning | error | error | warning |
| `prose-style` R1 passive voice · R3 noun clusters | warning | warning | warning | warning |

`prose-style` checks the greppable half of
[`writing-style.md`](writing-style.md); the authoring skills carry the whole
contract as judgment. R1 and R3 are heuristics, so they are warnings at every
state and never ramp — a guess does not block a commit. The other four ramp with
this table's columns in `04_domain`, and are flat warnings in `03_features`,
`01_adr` and `05_screens`, which carry no `lifecycle:` for the columns to read.
The checks are **English-only in 0.7**: a project whose `output_language` is not
`en` gets one info-level note and no findings at all.

Drafts are deliberately permissive on lifecycle-coupled rules (`stable-blockers`, `touched-entity-lifecycle`) but the mechanical and coherence tiers apply unconditionally — type drift, broken references, missing sections, and TODO sludge silently break later promotion otherwise.

## How `promote` walks

`/inspire_domain promote {id}` confirms the target state, then re-runs the gates that would apply at that state. If any error finding is emitted, the promotion is refused — operator fixes, then retries.

- `draft → accepted` — confirm explicitly; the mechanical and coherence tiers already applied at draft, so promotion is a contract-locking act.
- `accepted → stable` — run stable-blockers + touched-entity-lifecycle; refuse if any `requires` target is not yet stable, or any touched entity is below `accepted`. The two gates are **one-directional**: stable actions need their `requires:` deps at `stable` and their touched entities at ≥ `accepted`. Entities promote independently; the bipartite touch graph means stabilising an entity never has consumer-side preconditions.
- `stable → accepted` (regression) — confirm explicitly; no gates rerun (the contract is loosening, not tightening).
- `accepted → draft` (regression) — confirm explicitly; no gates rerun (drafts are permissive).
- `{any} → superseded` — confirm explicitly; require `superseded_by` to point to an existing action; do not rerun other gates (the descriptor is being archived, not promoted).
- Reverse from `superseded` — refused; create a new descriptor instead.

After a promotion that changes the action's behavior visible to consumers (typically `→ stable` or `→ superseded`), the agent re-runs the consolidation step so the per-entity document (`{module}.{entity}.md`) reflects the new lifecycle state in its writer/reader annotations.

## Regression — when to allow

A `stable → accepted` regression is unusual but legitimate when:

- A downstream constraint surfaces post-promotion (e.g., a new compliance gate requires re-design)
- A dependency was demoted, so this action's `stable-blockers` invariant breaks and the action is demoted in lockstep

Regression to `draft` is rarer; usually it indicates the action should be `superseded` and replaced. `promote` asks which one the operator means.

## `superseded_by` contract

The pointer is required and must resolve to an existing action in the tree. The replacement action need not (and usually does not) live in the same module — supersession can be cross-module. `acyclic-deps` ignores `superseded_by` edges (they're not part of the runtime requires graph).
