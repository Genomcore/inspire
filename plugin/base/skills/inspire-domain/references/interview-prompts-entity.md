# Interview prompts — entity document

A **categorical prompt catalogue** for the entity-document socratic interview. The skill loads this file when authoring a new entity doc, when an action introduces a field that doesn't yet appear in `## Fields`, or when an operator asks to revise an entity's design. Each prompt block lists the categorical question the skill always asks, plus 1–3 design-probing follow-ups for surfacing implicit decisions.

These prompts are **not verbatim scripts**. The skill never reads them out as-is. Claude generates *specific* probes from these categorical templates during a real interview, weaving the operator's own language (entity id, field names, neighboring entities, feature anchors) into the question. The catalogue's role is to guarantee no section is skipped and every section gets at least one design-forcing pass.

Section structure here mirrors the entity document format defined in [`../SKILL.md`](../SKILL.md) under *Entity document format*. The four operator-authored sections (`## Purpose`, `## Rationale`, `## Invariants`, `## Fields`) plus per-field H3 sub-sections are what the interview shapes; `## Touched by` is auto-populated by consolidation and is **not** interviewed.

The interview cadence is **one question at a time**. Entity docs are where the discussion-forcing discipline lives — particularly the field-addition probe — so the skill must be willing to pause an action-descriptor authoring flow to interview the entity doc before letting a new field row land. Never present a numbered decision tree.

## Authoring contexts

An entity-doc interview runs in one of three contexts. The triggering context determines which prompt blocks below are in-scope and which are skipped.

- **Fresh authoring.** The entity document does not yet exist; the operator is creating it as a standalone artefact or as a side-effect of authoring the first action that touches it. Walk all four sections: `## Purpose` → `## Rationale` → `## Invariants` → `## Fields`. Per-field H3 prompts run inside the Fields pass.
- **Field addition mid-flow.** An action descriptor introduces a field not yet in `## Fields`. Consolidation pauses; the skill interviews **only** the Rationale (`## Rationale prompts → discussion-forcing probe`) and, if warranted, a per-field H3 — *before* the new row lands in the table. Other sections are not re-interviewed.
- **Targeted revision.** The operator invokes `update` against an existing entity doc. Only the sections named in the invocation are walked; the discussion-forcing probe still fires if revisions touch the Fields table.

The skill picks the context from the invocation; this file does not enforce it. The catalogue is a superset — every prompt block can apply, but only the in-scope ones run in any given interview.

## Purpose prompts

### Categorical
Ask what this entity is, and why it exists as a discrete object in the system. The answer becomes the body of `## Purpose`, with feature/ADR wikilinks woven prosaically into the sentence that makes each claim.

### Probes
- **Boundary-on-existence probe.** "Why is this its own entity rather than a field on `<adjacent-entity>`? E.g. why is `auth::password` separate from `auth::user`, not a column on it?" Always ask for any new entity — surfacing the boundary justification is the whole point of `## Purpose`.
- **Single-source-of-truth probe.** "Is this entity *the* canonical record of `<concept>`, or is it a projection / cache / mirror of something owned elsewhere?" Use whenever the entity's relationship to upstream data isn't obvious from the name.
- **Lifecycle probe.** "Rows in this entity — are they immutable once created, mutable, or lifecycled through states? The Purpose sentence should hint at the answer; the invariants will pin it down." Use when the entity is non-trivially mutable.

## Rationale prompts

### Categorical
Ask which feature sections and ADRs ground the design decisions — why this entity exists at all, why these fields are the right shape, what motivates the structure. The answer becomes the body of `## Rationale`, the longest operator-authored section, with inline prosaic wikilinks throughout.

### Probes
- **Field-shape probe.** "Why is the field shape minimal in this direction (no `display_name`, no `phone`, no `tenant_id`) and rich in that one (`password_hash` + `last_seen_at` + `created_at`)? What forces the shape — auth-provider integration constraints, the identity model in [[adr-auth-01-identity-model]], something else?" Use whenever the field set has visible asymmetries.
- **ADR-grounding probe.** "Which ADR — if any — locks in the design call? If there's no ADR but the rationale is >10 lines, that's a signal an ADR is missing." Use whenever the rationale leans heavily on undocumented platform-level decisions.
- **Discussion-forcing probe (field addition).** "Adding `<field>` to this entity. What's the design call behind it? — I'll fold the rationale into `## Rationale` before the row lands in `## Fields`." This is the **load-bearing probe**. Always trigger it when an action descriptor introduces a field not yet in the entity doc. The new field row blocks on the Rationale update.
- **Out-of-scope probe.** "What does this entity *not* carry that a reader might expect — e.g. `auth::user` has no `display_name` because the display layer reads from a separate profile entity? Calling out the non-fields helps future readers." Use for entities whose minimal shape is a deliberate design choice.

## Invariants prompts

### Categorical
Ask which operator-facing assertions must hold across the entity — uniqueness, ordering, immutability, referential integrity. The answer becomes the `## Invariants` bullet list. `None beyond Fields constraints.` is a valid one-line body.

### Probes
- **Uniqueness probe.** "Are any field values unique across rows? `<field>` looks like a candidate (email, slug, external id). Is the uniqueness enforced at the DB layer, the action layer, or both?" Use for any entity with identifier-shaped fields beyond `id`.
- **Immutability probe.** "Any fields that are write-once (set at insert, never updated)? `created_at` is the obvious one — are there others (e.g. an external id, a creator reference)?" Always ask; immutability invariants are routinely under-declared.
- **Cross-action probe.** "Invariant says `password_hash` is write-only — no read action returns it. Walk back through the action descriptors: does that hold? If `<action>` returns it, either the invariant or the action is wrong." Use whenever an invariant constrains visibility (write-only, read-only, never-exposed).
- **Brevity probe.** "If nothing extra holds beyond what the Fields table already constrains, the body can be `None beyond Fields constraints.` — the section must exist but a one-liner is acceptable. Is that the case here?" Use whenever the operator hesitates or starts inventing weak invariants.

## Fields prompts

### Categorical
Ask for the field shape — type, notes, and (for non-self-evident fields) whether a per-field H3 rationale is warranted. The answer drives the `## Fields` table rows and any per-field `### {field-name}` H3 sub-sections placed immediately under it. Field rows are largely emergent during consolidation (joined from every action's `## Entities` declarations), but the design call behind each row is operator-authored.

### Probes
- **Type probe.** "Type for `<field>` — canonical semantic type (`email`, `password`, `uuid`, `timestamp`), or a primitive? Canonical types route to platform-wide validation; primitives put the burden on the action's behavior section." Use for every non-`id`, non-`created_at` field.
- **Per-field-H3 probe.** "Does `<field>` need a per-field H3, or is it self-evident from the Notes column? Use H3 when the field's behavior depends on a system-wide design call (algorithm choice, nullability semantics, lifecycle constraints); skip it for obvious cases (`id`, `created_at`)." Always ask; the absence of an H3 should itself be a deliberate signal.
- **Field-coverage probe.** "Field `<field>` is declared in the entity but no action descriptor reads it — is that intentional (planned future action, write-only for audit) or do we need to add a reader before promoting to `accepted`/`stable`?" Use during entity-doc review; surfaces orphan-write fields that `entity-coherence` will eventually flag.
- **Notes-vs-H3 boundary probe.** "Notes column for `<field>` is getting long — `Unique across rows; case-insensitive comparison; trimmed before write`. That's three different rules. Promote to a per-field H3?" Use whenever a Notes cell tries to carry more than one design point.
- **Nullability probe.** "Is `<field>` nullable, and if so what distinguishes null from a default value? `last_seen_at = null` ('never logged in') vs. `last_seen_at = created_at` (synthetic) is the classic example — the choice is load-bearing for downstream consumers." Use for any nullable field.

## Per-field H3 prompts

### Categorical
For each field whose Notes column can't carry the design call, ask for the rationale narrative — what motivates the choice, which ADR/feature grounds it, what consumers need to know. The answer becomes a `### {field-name}` H3 sub-section placed immediately under the Fields table, in field-table order.

### Probes
- **Algorithm-as-system-setting probe.** "`<field>` carries `<credential / hash / token>` material. Is the algorithm a per-row column or a system-wide setting? If system-wide, the H3 should ground the choice in the relevant ADR and explain why per-row would have been wrong." Use for any cryptographic / opaque-blob field.
- **Cross-action-reference probe.** "The H3 mentions `<concept>` (verification, archival, derivation). Should it link to the action that handles that concept (`[[module.entity.action|module::entity::action]]`)? Cross-action wikilinks help future readers trace behavior without grepping." Use whenever the H3 names an operation rather than a fact.
- **Length probe.** "The H3 is approaching ADR length (>10 lines, multiple design tradeoffs). Should it stay here, or does the decision warrant its own ADR with the H3 reduced to a sentence + wikilink?" Use whenever an H3 drifts past a paragraph or two — the rationale-vs-ADR threshold matches the project's general convention.

## Cross-cutting probes

A handful of probes don't belong to a single section but run *across* the interview, surfaced whenever the dialogue brushes against them. Treat these as ambient — not catalogued under one section, but always available.

- **Entity-vs-feature probe.** "Is this an *entity* (the data shape) or a *feature* (a capability)? Features live in PDDs and decompose into actions; entities are the data objects the actions touch. If the operator says 'a feature for resetting passwords,' that's an action on `auth::password`, not a new entity." Surface whenever the framing conflates the two.
- **Action-coverage probe.** "Right now this entity has `<N>` actions touching it: `<list>`. Is the action set complete for the entity's intended lifecycle — create, read, list, update, delete, plus any domain-specific verbs — or are some intentionally missing? Missing readers on written fields is the most common gap." Use at the end of a fresh-authoring interview, before consolidation runs.
- **Naming-consistency probe.** "Entity id `<id>` — does it match conventions in the rest of the module (singular noun, snake_case, no `_entity` suffix)? Consistency at review time avoids churn later." Use when the proposed id has any divergence from neighboring entities.
- **Promotion-readiness probe.** "Lifecycle target — `draft`, `accepted`, or `stable`? `accepted` requires the operator-authored sections to be substantive (no stub Rationale). Entities promote independently of their actions — the bipartite touch graph means stabilising an entity never has consumer-side preconditions." Use whenever lifecycle is named in the invocation or comes up mid-interview.
