# Entity document format

The format spec for entity documents. SKILL.md owns the interview cadence and lifecycle; this file owns the on-disk shape.

An entity document lives at `.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md` — one fewer dotted segment than the action filenames sharing the directory. Segment count is what tells the tooling the two object kinds apart.

The entity document is a **design-discipline artefact** — it captures *why* this entity exists as a discrete object and *what motivates* its field shape — not a thin projection of the actions that touch it.

## Canonical shape

```markdown
---
id: auth.user
module: auth
entity: user
lifecycle: draft           # draft | accepted | stable | superseded
---

## Purpose
Operator-facing prose stating what this entity is and why it exists as a discrete object, with inline prosaic wikilinks back to feature/ADR. Required, non-empty.

## Rationale
feature/ADR grounding for the design decisions — why this entity exists at all, why these fields are the right shape, what motivates the structure. Inline prosaic wikilinks throughout. Adding or changing a field requires updating this section: that is the discussion-forcing discipline.

## Invariants
Operator-facing assertions that must hold across the entity — uniqueness, ordering, immutability, referential integrity. May be `None beyond Fields constraints.` when no extra invariants apply; the section must be present but a one-liner is acceptable.

## Fields

| Field          | Type      | Notes                                  |
|----------------|-----------|----------------------------------------|
| `id`           | uuid      | Primary key.                           |
| `email`        | email     | Unique across `auth::user` rows.       |
| `password_hash`| string    | Algorithm decided system-wide.         |
| `created_at`   | timestamp | Set at insert; never updated.          |

### password_hash
Opt-in per-field H3 sub-section. Use for fields that need rationale, design notes, or non-obvious behavior — e.g. why the hash algorithm is a system-level setting rather than a per-field choice, with inline wikilink to [[adr-auth-02-password-hashing]]. Skip for self-evident fields (`id`, `created_at`).

## Touched by

| Action                                                  | Touch  | Notes                          |
|---------------------------------------------------------|--------|--------------------------------|
| [[auth.user.create|auth::user::create]]                 | write  | Inserts the row.               |
| [[auth.user.find|auth::user::find]]                     | read   | Looks up by `id` or `email`.   |
```

## Externally populated entities

Some entities' rows are populated outside the SDD action layer — build-time catalogs (e.g. [[platform.action]]), sync mirrors of external systems, vendor feeds. Set `population: external` in frontmatter to mark these:

```markdown
---
id: platform.action
module: platform
entity: action
lifecycle: draft
population: external
---
```

The enum is `internal` (default, omit the field) | `external`. The marker is a **structural claim**: no SDD-layer action writes this entity. It is not a runtime-immutability claim about the data itself — the rows may still be mutated by mechanisms outside SDD scope.

Three tooling consequences:

- `entity-coherence`'s `field-unsourced` check is suppressed for fields on `population: external` entities (no SDD writer is the design, not a gap).
- `field-coverage` skips `population: external` entities entirely (whole-entity reads do not enumerate fields, so per-field coverage is not a meaningful check).
- A new `write-on-external` check errors when any action declares a write touch (`create`, `update`, `delete`, `append`, `replace`) on a `population: external` entity. The marker is a contract, not just a permission slip.

## Section conventions

Six sections, in order: 4 mandatory (`## Purpose`, `## Rationale`, `## Invariants`, `## Fields`), 1 opt-in per field (`### {field-name}` H3 sub-sections, placed immediately after the Fields table), 1 auto-populated (`## Touched by`).

- **`## Purpose`** — non-empty, operator-readable prose stating what the entity is and why it exists as a discrete object. Back-sourcing is **prosaic**: wikilinks weave into the sentence that makes the claim.
- **`## Rationale`** — operator-authored, feature/ADR-grounded. The **discussion-forcing function**: when an action introduces a new field, the agent surfaces the rationale question and waits for the operator to update this section *before* the new field row lands in `## Fields`. This is what keeps the entity shape an act of design rather than an emergent residue of action authoring.
- **`## Invariants`** — operator-authored. `None beyond Fields constraints.` is a valid one-line body; the section must be present, but brevity is welcome when there is genuinely nothing extra to assert.
- **`## Fields`** — `| Field | Type | Notes |` table with backticked field names. The row set is **largely emergent** — populated and reconciled by the agent during consolidation from every action descriptor's `## Entities` declarations — but each row exists because some action touches the field, and adding one forces a `## Rationale` update.
- **`### {field-name}`** — opt-in per-field rationale, immediately under the Fields table. Use for fields whose behavior or design needs more than the Notes column can carry. Skip for self-evident fields. Inline wikilinks where claims need sourcing.
- **`## Touched by`** — auto-populated by consolidation: `| Action | Touch | Notes |` table. **Touch values**: `read` · `write` · `list` · `delete`. Action ids use pipe-syntax wikilinks (`[[module.entity.action|module::entity::action]]`). Operators do not hand-edit this section; it is rewritten on every consolidation pass.

**No `## Findings`, no `## Used by`.** Files state present truth only — findings live in `review` output (git history is the audit trail), and the V2 `## Used by` section is now `## Touched by` with explicit touch semantics.

## Entity lifecycle (symmetric with actions)

Entity documents carry a `lifecycle:` frontmatter field with the **same 4-state enum** as actions: `draft → accepted → stable → superseded`. The states have the same meaning per [[lifecycle-rules]] — `draft` is permissive design space, `accepted` locks the shape, `stable` is release-grade, `superseded` is the terminal escape hatch. `define` creates entities at `draft`; `promote` and `demote` walk both object kinds through the same state machine.

**Promotion gating is one-directional.** A `lifecycle: stable` action requires every entity it touches (every entry in its `## Entities` section) to be at `lifecycle: accepted` or higher. Entities promote **independently** of the actions touching them — promoting an entity never requires its callers to be at any particular lifecycle. The rule enforces only one direction: stabilising an action forces its touched entities to be at least accepted; nothing forces the reverse.

The touch graph is **bipartite** (actions ↔ entities only) and therefore cycle-free by construction — cross-object cycles cannot form, so the gate is a simple per-action scan rather than a transitive walk. The action-to-action `requires:` graph is governed separately by `acyclic-deps` + `stable-blockers`.

Tooling: the gate is enforced by `.claude/bin/touched-entity-lifecycle.sh` (severity: error), wired into `review.sh`'s default rule list. The rule scans every `lifecycle: stable` action, resolves each touched entity id (colon form, e.g. `auth::user`) to its entity document on disk, and emits a finding if the document's `lifecycle:` is below `accepted` (or the document is missing). It does **not** apply to draft or accepted actions — those may touch entities at any lifecycle, including `draft`.

## Wikilink convention

Identical to actions: pipe-syntax `[[module.entity|module::entity]]` for entity refs, `[[module.entity.action|module::entity::action]]` for action refs.
