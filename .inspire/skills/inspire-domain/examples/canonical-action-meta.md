## A meta/dispatch action — `platform::action::resolve`

The canonical example (`canonical-action.md`) shows `auth::user::create` — a data-noun action where the entity is `auth::user`, a row in a table. But many SDD actions are **meta or dispatch verbs**: they read or manipulate other actions, configs, or system manifests, not domain data rows. This example shows what one of those looks like, and demonstrates the silent **plural→singular canonicalization** that happens between feature and SDD.

## feature source

The platform module's Action Catalog declares (in `.inspire_kb/02_modules/platform.md`):

| Action | Description | Priority |
|---|---|---|
| `platform::actions::resolve` | Resolve action manifest by id | H |
| `platform::actions::list` | List actions, filtered by module/source | H, M |

Note the **plural `actions` subsystem name** — that's the feature convention. The SDD canonicalizes this to singular: `platform::action::resolve`. The intention is identical; this is a known naming-convention shift between the layers, applied silently by `/inspire_module scan` when it canonicalizes candidate ids. **The agent does NOT surface this as a "naming reconciliation" question** — there's no decision to make.

## SDD descriptor

```markdown
---
id: platform::action::resolve
module: platform
entity: action
action: resolve
lifecycle: draft
requires: []
superseded_by: null
---

## Purpose
Resolve a registered action's manifest by id. The [[platform-action-catalog|action catalog]] is the runtime source of truth for which capabilities the platform exposes, as defined in [[adr-plt-06-action-catalog]]; this verb is its read entry point.

## Inputs

| Parameter | Type   | Required | Description                                |
|-----------|--------|----------|--------------------------------------------|
| `id`      | string | yes      | The action id, e.g. `"auth::user::create"`.|

## Outputs

A single [[platform.action|platform::action]] entity — its frontmatter plus the resolved manifest.

## Entities

### [[platform.action|platform::action]]
**As input:** id · **Effect:** read

| Field      | Touch | Type   | Mapping            | Notes                                  |
|------------|-------|--------|--------------------|----------------------------------------|
| `id`       | read  | string | `matches input.id` |                                        |
| `manifest` | read  | json   | —                  | The descriptor's resolved contract.    |

## Behavior
1. Resolve `id` against the action catalog index defined in [[adr-plt-06-action-catalog]].
2. Return the descriptor's frontmatter and resolved manifest as JSON.
3. If the id is unknown → `action_not_found`.

## Errors
- `action_not_found` — operator-facing message: "Action {id} not found in the catalog."
```

## What's notable

- **The `id:` field is singular** (`platform::action::resolve`) even though the feature writes it plural. Both are correct — they're the same action expressed at different layers. The folder layout follows the SDD id: `.inspire_kb/04_domain/platform/action/platform.action.resolve.md`.

- **The entity `platform::action` is meta**, not a data noun. The fields (`id`, `manifest`) are properties of the action manifest itself, not columns of a `platform_action` table. There's no SQL `CREATE TABLE` for this entity — the source of truth is the filesystem (action descriptors and the catalog index).

- **The Outputs section uses the whole-entity 1-liner.** Since `resolve` returns the entire `platform::action` entity, the contract points at the entity document instead of restating its field shape. The SDD descriptor is a logical contract — wire-shape translations live in surface-binding artifacts downstream.

- **`entity-coherence` on meta entities is a known soft spot.** The rule expects every read field to have at least one `Touch=written` declaration somewhere. Here, the writers are *operators authoring descriptors* — not other actions. If `field-unsourced` fires on a meta entity, the fix (not yet implemented) is a `kind: meta` annotation on the `### [[platform.action|platform::action]]` subheader that tells the rule "this entity's fields are authored, not action-written; skip field-unsourced." Until then, the warning is acceptable noise.

- **The back-source wikilinks** in `## Purpose` and `## Behavior` tie this descriptor to both the feature's action-catalog row and the governing ADR — woven into the prose that makes the claim, not appended as trailing references. An operator reading this descriptor doesn't need to know about the plural→singular shift; only that the wikilinks resolve.

## When to use the meta shape vs. the data-noun shape

| Action looks like | Use canonical-action.md shape | Use this meta shape |
|---|---|---|
| Writes/reads a domain row (`auth::user`, `auth::password`) | yes | |
| Reads/manipulates a catalog, manifest, or config | | yes |
| Orchestrates other actions but writes a row of its own | yes (with multi-entity pattern) | |
| Pure dispatcher with no row write | | yes |

If you're not sure: data-noun shape is the default. The meta shape is only for verbs whose primary entity is itself an SDD artifact (action manifest, capability declaration, action-catalog row).
