# Effect × Touch matrix

Reference for valid `**As input:**` × `**Effect:**` × `Touch` combinations in the `## Entities` h3 sub-sections of an action descriptor.

`**As input:**` says how the entity is identified for this action (`id`, `shape`, `—`, a specific field, etc.). `**Effect:**` says what the action does to the entity (`create`, `read`, `update`, `delete`, `append`, `replace`). `Touch` on each field is `read` or `written`.

Most actions follow a small number of well-formed shapes. This matrix documents them so the operator and agent can lean on convention rather than re-deriving the table each time.

## Canonical action shapes

| Action kind | As input | Effect | Field Touch pattern | Typical mapping column |
|-------------|----------|--------|---------------------|------------------------|
| `create` | `shape` | `create` | All persistent fields `written` | `uuid()`, `now()`, `input.{field}`, `hash(input.{field})` |
| `read` (whole)   | `id`                 | `read-whole` | PK / filter fields `read`; returned fields not enumerated (covered by `read-whole`) | `input.{field}` for keys       |
| `read` (partial) | `id`                 | `read`       | Every returned field explicitly `read`                                              | `—` (PK), `—` (returned fields) |
| `list`           | `—` or filter fields | `read-whole` | Filter fields `read`; returned fields not enumerated                                | `—`                            |
| `update` | `id` | `update` | PK fields `read`; changed fields `written`; unchanged fields not declared | `input.{field}` for changed fields |
| `replace` | `id` | `replace` | PK fields `read`; all persistent fields `written` | `input.{field}` for all |
| `delete` | `id` | `delete` | No field declarations needed (the row, not the fields, is the unit) | — |
| `append` | (depends) | `append` | Appended fields `written`; existing fields not declared | `now()`, `input.{field}` |

## Mixed-entity actions (orchestrators)

A single action may declare multiple `### [[module::entity]]` sub-sections, one per touched entity. Each sub-section follows the canonical shapes independently. Typical pattern:

- A primary write entity (`create` or `update` Effect)
- One or more event log entities (`append` Effect, with metadata fields like `event_type`, `actor_id`, `at`)
- Zero or more lookup entities (`read` Effect; PKs `read`, fields `read` for the data the action needs)

The orchestrator example in `examples/orchestrator.md` shows the canonical multi-entity form.

## Edge cases

- **`read` action with `Touch=written` field** — this is the canonical shape for derived/computed read responses where the action persists a denormalized cache row. Document the cache rationale in the action's `## Purpose` section.
- **Pure validators** — an action that only validates (no entity side-effect) declares no `## Entities` sub-sections. `Effect: validated` is allowed for completeness in feature-traceability, but is rare; usually a validator is a step in a larger action's `## Behavior`, not its own descriptor.

## How the matrix is enforced

The matrix is **descriptive, not prescriptive**: there's no rule that fails an action for declaring a non-canonical shape. But two `entity-coherence` rules constrain combinations downstream:

- A field declared `Touch=read` on entity R but never declared `Touch=written` on R (across all actions) → `field-unsourced` error. The canonical `read` shape relies on some `create` or `update` action having declared the writer.
- A field declared `Touch=written` on R but never declared `Touch=read` on R → `field-orphan-write` warning. "Writing for no-one." If the field is intentional (e.g. a write-only audit trail), suppress by declaring at least one `read` action on it — usually the same module has a reporting action that needs it.
- A `read-whole` effect on an entity desugars to per-field `read` touches across every field declared in the entity document, at rule-check time (via `sdd_expand_whole_reads`). An entity marked `population: external` (see `format-entity.md`) suppresses both the resulting `field-unsourced` errors and the entity's `field-uncovered` findings.

If your action's shape doesn't fit any canonical row above, that's a smell worth pausing on. Either decompose into smaller actions, or document the non-canonical shape in `## Purpose` so a future reader knows it was intentional.
