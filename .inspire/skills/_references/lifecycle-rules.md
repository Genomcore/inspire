# Lifecycle rules (shared reference)

Every SDD object — **action descriptor** (`.inspire_kb/04_specs/{module}/{entity}/{module}.{entity}.{action}.md`) and **entity document** (`.inspire_kb/04_specs/{module}/{entity}/{module}.{entity}.md`) alike — carries a `lifecycle:` field in its frontmatter. The lifecycle controls which quality_lib rules apply and what transitions the agent will offer. The two object kinds share the same 4-state enum and the same state machine.

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

Forward progression: `draft → accepted → stable`. Regression (`stable → accepted`, `accepted → draft`) is permitted when a downstream constraint forces it — `/inspire_object promote` walks both directions, just confirms more carefully on regressions.

`superseded` is the escape hatch. An action in any state can be marked superseded; the descriptor stays in the tree, carries `superseded_by: "[[module::entity::new-action]]"`, and is dropped from the in-scope `requires` graph (other actions that listed it must be updated separately — `/inspire_object graph` flags affected callers).

## Per-state rule gates

The quality gate (D24) — 9 rule families across three severity tiers running at every commit:

### Tier 1 — Mechanical blockers (always error)

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `lifecycle-valid` (frontmatter `lifecycle:` present + enum-valid) | error | error | error | error |
| `requires-resolves` (`requires:` resolves to existing action) | error | error | error | error |
| `superseded-by-resolves` (`superseded_by:` resolves when set) | error | error | error | error |
| `acyclic-deps` (no self-loop, no cycle) | error | error | error | error |

### Tier 2 — Coherence blockers (error from draft+)

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `sections-present` (mandatory body sections present + non-empty) | error | error | error | error |
| `no-todos` (no TODO/FIXME markers — D19) | error | error | error | error |
| `action-fields-in-entity` (action touch declarations match entity Fields table) | error | error | error | error |
| `entity-coherence` (field-conflict, unsourced — error; orphan-write — warning) | enforced | enforced | enforced | exempt |
| `stable-blockers` (`requires:` deps must be stable) | exempt | exempt | error | exempt |
| `touched-entity-lifecycle` (touched entities must be ≥ accepted) | exempt | exempt | error | exempt |

### Tier 3 — Lifecycle-progressive (warning at draft, error at accepted+)

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `field-coverage` (every entity Fields row touched by ≥1 action) | warning | error | error | warning |
| `rationale-wikilink` (≥1 wikilink in Rationale / Purpose / Behavior) | warning | error | error | warning |
| `wikilinks-resolve` (every `[[wikilink]]` resolves to a file) | warning | error | error | warning |

The three tier-3 rules ramp severity by the *current object's* lifecycle, not by the lifecycle of the targets they reference. A draft entity missing rationale wikilinks emits a warning; the same entity at `accepted` emits an error and blocks promotion.

Drafts are deliberately permissive on lifecycle-coupled rules (`stable-blockers`, `touched-entity-lifecycle`) but the mechanical and coherence tiers apply unconditionally — type drift, broken references, missing sections, and TODO sludge silently break later promotion otherwise.

## How `promote` walks

`/inspire_object promote {id}` confirms the target state, then re-runs the gates that would apply at that state. If any error finding is emitted, the promotion is refused — operator fixes, then retries.

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
