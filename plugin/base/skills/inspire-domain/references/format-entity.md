# Entity document format

The format spec for entity documents. SKILL.md owns the interview cadence and lifecycle; this file owns the on-disk shape.

An entity document lives at `inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md` — one fewer dotted segment than the action filenames sharing the directory. Segment count is what tells the tooling the two object kinds apart.

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
- `I1` — unique(org_id, email) — Email is unique per organisation, not globally, because the identity model in [[adr-auth-01-identity-model]] scopes principals to an org.
- `I2` — A suspended account keeps every row it wrote; suspension changes what may be read, never what exists.

## Fields

| Field          | Type      | Notes                                  |
|----------------|-----------|----------------------------------------|
| `id`           | uuid      | Primary key.                           |
| `org_id`       | uuid      | The owning organisation.               |
| `email`        | email     | The canonical identity handle.         |
| `password_hash`| string    | Algorithm decided system-wide.         |
| `created_at`   | timestamp | The audit-timeline anchor.             |

### id
Constraints: `nonnull, unique, immutable`

### org_id
Constraints: `nonnull, immutable, references(auth.org)`

### email
Constraints: `nonnull, pattern(/.+@.+/)`

Per-field rationale follows the Constraints line, in prose, with inline wikilinks where a claim needs sourcing — here, why the pattern is deliberately permissive and defers to [[auth-email-validation|the email-validation rules]].

### password_hash
Constraints: `nonnull`

Use the per-field H3 for fields that need rationale, design notes, or non-obvious behavior — e.g. why the hash algorithm is a system-level setting rather than a per-field choice, with inline wikilink to [[adr-auth-02-password-hashing]].

### created_at
Constraints: `nonnull, immutable, default(now)`

## Touched by

| Action                                                  | Touch  | Notes                          |
|---------------------------------------------------------|--------|--------------------------------|
| [[auth.user.create|auth::user::create]]                 | write  | Inserts the row.               |
| [[auth.user.find|auth::user::find]]                     | read   | Looks up by `id` or `email`.   |
```

## Externally populated entities

_Reference material about the `population: external` frontmatter marker below — not
a section of an entity document; the entity document's own section list is defined
in [Section conventions](#section-conventions)._

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

Six sections, in order: 4 mandatory (`## Purpose`, `## Rationale`, `## Invariants`, `## Fields`), 1 per-field H3 (`### {field-name}` sub-sections, placed immediately after the Fields table — mandatory for a constrained field, opt-in otherwise), 1 auto-populated (`## Touched by`).

- **`## Purpose`** — non-empty, operator-readable prose stating what the entity is and why it exists as a discrete object. Back-sourcing is **prosaic**: wikilinks weave into the sentence that makes the claim.
- **`## Rationale`** — operator-authored, feature/ADR-grounded. The **discussion-forcing function**: when an action introduces a new field, the agent surfaces the rationale question and waits for the operator to update this section *before* the new field row lands in `## Fields`. This is what keeps the entity shape an act of design rather than an emergent residue of action authoring.
- **`## Invariants`** — operator-authored, and **keyed**: each entry is `` - `I{n}` — {head} — {prose} `` (or `` - `I{n}` — {prose} `` when no head fits), per [`keyed-heads.md`](../../_references/keyed-heads.md). Heads come from V2 there — the multi-field and relational predicates a single field's own line cannot express. `None beyond Fields constraints.` remains the valid one-line body; the section must be present, but brevity is welcome when there is genuinely nothing extra to assert.
- **`## Fields`** — `| Field | Type | Notes |` table with backticked field names, **unchanged**: constraints do not live in the table. The row set is **largely emergent** — populated and reconciled by the agent during consolidation from every action descriptor's `## Entities` declarations — but each row exists because some action touches the field, and adding one forces a `## Rationale` update. [`type-mapping.md`](type-mapping.md) is the authority for the `Type` vocabulary and `Mapping` tokens.
- **`### {field-name}`** — per-field sub-section, immediately under the Fields table, in field-table order. Its **first line carries the field's constraints** when it has any: `` Constraints: `nonnull, unique, immutable` `` — the closed V1 vocabulary of [`keyed-heads.md`](../../_references/keyed-heads.md). Everything after that line is the per-field rationale prose: what motivates the design, which ADR or feature grounds it, what consumers need to know. A constrained field **must** carry the H3, even when the Constraints line is all it has to say; an unconstrained field needs one only when its design needs narrating.
- **`## Touched by`** — auto-populated by consolidation: `| Action | Touch | Notes |` table. **Touch values**: `read` · `write` · `list` · `delete`. Action ids use pipe-syntax wikilinks (`[[module.entity.action|module::entity::action]]`). Operators do not hand-edit this section; it is rewritten on every consolidation pass.

**No `## Findings`, no `## Used by`.** Files state present truth only — findings live in `review` output (git history is the audit trail), and the V2 `## Used by` section is now `## Touched by` with explicit touch semantics.

## Constraints and invariants

Two homes, split by how many fields a rule spans. The grammar, the closed
vocabularies, the derived claim ids and the oracle split all live in
[`keyed-heads.md`](../../_references/keyed-heads.md); what follows is only what
is specific to entity documents.

**One field → its own `Constraints:` line.** `` Constraints: `nonnull, unique, immutable` ``, the first line of that field's H3. The list is closed
vocabulary V1, comma-separated, inside one backtick span. A word outside V1, or
a V1 word at the wrong arity, is an error — it is a typo, not prose, and a typo
in a constraint is a claim that silently stops being asserted.

**Two or more fields, or a relation → a named invariant.** `` - `I3` — unique(org_id, email) — {prose} `` in `## Invariants`. This is why the
composite case has a home at all: a rule about a tuple has no single field to
live under.

**Fields are nullable by default.** There is no `nullable` word — absence of
`nonnull` is nullability. The quiet case is the common one; the marked case is
the requirement.

**Two per-field rules that are not conventions but checks:**

- **`id` always carries a Constraints line.** Every entity has an `id`, and its
  constraints are always real (`nonnull, unique, immutable` at minimum). That
  makes the `id` H3 the **deterministic marker** distinguishing an entity
  written in this format from one written before it — which is why a strict
  reader can refuse the old shape per-artifact instead of guessing. An entity
  with no `id` row at all is a separate defect, reported separately, so the
  marker can never pass vacuously.
- **A constraint stated twice drifts.** Once a constraint is on the Constraints
  line, the `Notes` cell says what the constraint *means* to a reader, not that
  it exists. "Unique across rows" in Notes next to `unique` on the line is two
  spellings of one fact; `review.sh` reports the leftover as a warning — a
  warning, because recognising a constraint word inside prose is a heuristic and
  a heuristic does not block anything.

## Entity lifecycle (symmetric with actions)

Entity documents carry a `lifecycle:` frontmatter field with the **same 4-state enum** as actions: `draft → accepted → stable → superseded`. The states have the same meaning per [[lifecycle-rules]] — `draft` is permissive design space, `accepted` locks the shape, `stable` is release-grade, `superseded` is the terminal escape hatch. `define` creates entities at `draft`; `promote` and `demote` walk both object kinds through the same state machine.

**Promotion gating is one-directional.** A `lifecycle: stable` action requires every entity it touches (every entry in its `## Entities` section) to be at `lifecycle: accepted` or higher. Entities promote **independently** of the actions touching them — promoting an entity never requires its callers to be at any particular lifecycle. The rule enforces only one direction: stabilising an action forces its touched entities to be at least accepted; nothing forces the reverse.

The touch graph is **bipartite** (actions ↔ entities only) and therefore cycle-free by construction — cross-object cycles cannot form, so the gate is a simple per-action scan rather than a transitive walk. The action-to-action `requires:` graph is governed separately by `acyclic-deps` + `stable-blockers`.

Tooling: the gate is enforced by `.inspire/bin/touched-entity-lifecycle.sh` (severity: error), wired into `review.sh`'s default rule list. The rule scans every `lifecycle: stable` action, resolves each touched entity id (colon form, e.g. `auth::user`) to its entity document on disk, and emits a finding if the document's `lifecycle:` is below `accepted` (or the document is missing). It does **not** apply to draft or accepted actions — those may touch entities at any lifecycle, including `draft`.

## Wikilink convention

Identical to actions: pipe-syntax `[[module.entity|module::entity]]` for entity refs, `[[module.entity.action|module::entity::action]]` for action refs.
