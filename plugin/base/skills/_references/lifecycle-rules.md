# Lifecycle rules (shared reference)

Every SDD object — **action descriptor** (`inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md`), **entity document** (`inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md`) and **screen file** (`inspire_kb/05_screens/**/{screen}.md`) alike — carries a `lifecycle:` field in its frontmatter. The lifecycle controls which quality_lib rules apply and what transitions the agent will offer. The three object kinds share the same 4-state enum and the same state machine; what each state *gates* differs per kind, and each owning skill says so ([`inspire-screens/references/screen-lifecycle.md`](../inspire-screens/references/screen-lifecycle.md) for screens).

## The 4-state enum

| State | Meaning |
|---|---|
| `draft` | In design. Free authoring; very few invariants enforced. |
| `accepted` | Design closed. The contract is being implemented; for entities, the field shape is locked; for screens, the bindings are locked. |
| `stable` | Implementation locked. For actions, all `requires:` deps and all touched entities must be at least accepted (entities must themselves be ≥ accepted; deps must be stable). For screens, every declared component is `**State:** implemented`. Treated as a release contract. |
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

`sections-present` splits its severity by **layer**, because two of the layers it
checks carry no `lifecycle:` field at all: a use-case file and an ADR have no
column to read, so nothing there can ramp, and every finding the rule makes in
`03_features` or `01_adr` is a **warning** at every moment of that artifact's life.
The table above is the `04_domain` half. Its second row is the exception within the
exception: the order check *does* ramp, because what a draft may still be reshaping
an accepted or stable object has fixed. The `05_screens` half is the § Screens
table below.

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

### Screens — the same columns, read in `05_screens`

Screen files carry `lifecycle:`, so the columns above are readable there too:

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `sections-present` (screen required parts: H1 · `**Features:**` line · non-empty `## Bindings`; and the retired `## Instantiation`) | warning | error | error | warning |
| `screen-coherence` (identity fields, keyed bindings, internal references, the pattern↔region join) | warning | error | error | warning |
| `screen-coherence` (duplicate `id`; two screens deriving one route in one shell) | error | error | error | error |
| `screen-coherence` (a `stable` screen declaring a `**State:** to-extract` component) | exempt | exempt | error | exempt |
| `wikilinks-resolve` (every `[[wikilink]]` in a screen resolves) | warning | error | error | warning |

A screen file with **no frontmatter at all** — every screen written before the
identity block existed — reads as `draft` and emits warnings only. That is the
migration path working as designed: nothing authored before 0.8 starts blocking a
commit, while the same file at `accepted` does.

The two identity rows that never ramp cannot fire on a pre-0.8 file at all: both
sides need declared frontmatter, and both findings are contradictions rather than
incompleteness. A contradiction blocks at every state.

`prose-style` is deliberately absent from this table. Style findings stay flat
warnings in every layer outside `04_domain`, screens included: a screen ramps on
the rules that describe its contract — its shape, its identity, its bindings —
never on the ones that read its prose.

### Style — the mechanical subset of the writing contract

| Rule | draft | accepted | stable | superseded |
|---|---|---|---|---|
| `prose-style` R2 sentence cap · R4 glossary synonyms · R5 paragraph length · R6 historical language | warning | error | error | warning |
| `prose-style` R1 passive voice · R3 noun clusters | warning | warning | warning | warning |

`prose-style` checks the greppable half of
[`writing-style.md`](writing-style.md); the authoring skills carry the whole
contract as judgment. R1 and R3 are heuristics, so they are warnings at every
state and never ramp — a guess does not block a commit. The other four ramp with
this table's columns in `04_domain` and are flat warnings everywhere else:
`03_features` and `01_adr` have no `lifecycle:` for the columns to read, and
`05_screens` has one that these checks deliberately do not read (§ Screens).
The checks are **English-only in 0.7**: a project whose `output_language` is not
`en` gets one info-level note and no findings at all.

Drafts are deliberately permissive on lifecycle-coupled rules (`stable-blockers`, `touched-entity-lifecycle`) but the mechanical and coherence tiers apply unconditionally — type drift, broken references, missing sections, and TODO sludge silently break later promotion otherwise.

## How `promote` walks

Each object kind is promoted by the skill that owns it — `/inspire_domain promote` for actions and entities, `/inspire_screens promote` for screens — and both walk the state machine above. The walk below is the domain one; the screen gates are [`screen-lifecycle.md`](../inspire-screens/references/screen-lifecycle.md) § How `promote` walks.

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
