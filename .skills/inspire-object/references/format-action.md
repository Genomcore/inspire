# Action descriptor format

The format spec for action descriptors. SKILL.md owns the interview cadence and lifecycle; this file owns the on-disk shape.

An action descriptor lives at `.inspire_kb/04_specs/{module}/{entity}/{module}.{entity}.{action}.md`. The full-dotted-id filename (e.g. `auth/user/auth.user.create.md`) disambiguates Obsidian tabs and Quick Switcher, where bare verb filenames like `create.md` recur across entities. Dots — not `::` — because Windows forbids `:` in filenames.

## Canonical shape

```markdown
---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: draft           # draft | accepted | stable | superseded
requires:
  - "[[auth.password.hash|auth::password::hash]]"
superseded_by: null        # required iff lifecycle == superseded
---

## Purpose
Create a new platform user account from an email + password pair. The [[auth-user-management|user-management subsystem]] is the source of truth for identity; this verb is its admin-side account-provisioning entry point. Identity model, scopes, and the Kratos integration are defined in [[adr-auth-01-kratos-scopes-keto]].

## Inputs

| Parameter  | Type     | Required | Description                              |
|------------|----------|----------|------------------------------------------|
| `email`    | email    | yes      | Account login email. Must be unique.     |
| `password` | password | yes      | Plaintext password; hashed before write. |

## Outputs

| Field | Type | Description                |
|-------|------|----------------------------|
| `id`  | uuid | The newly created user id. |

## Entities

### [[auth.user|auth::user]]
**Effect:** create

| Field          | Touch   | Type      | Mapping       | Notes |
|----------------|---------|-----------|---------------|-------|
| `id`           | written | uuid      | `uuid()`      |       |
| `email`        | written | email     | `input.email` |       |
| `created_at`   | written | timestamp | `now()`       |       |

## Behavior
1. Validate the email format against the constraints described in [[pdd-auth-user-management#email-constraints|the user-management email rules]].
2. Hash the password using [[auth.password.hash|auth::password::hash]], following the Kratos integration model in [[adr-auth-01-kratos-scopes-keto]].
3. Persist a new user row with the hashed credential.

## Errors
- `email_exists` — operator-facing message: "An account already exists with that email."
```

## Frontmatter

- **No H1 heading.** The id lives in frontmatter `id:` and is reconstructible from the file path, so a leading `# {id}` heading would be the third repetition of the same information. The body starts directly with `## Purpose`.
- `lifecycle` controls which quality_lib rules apply. See [`lifecycle-rules.md`](../../_references/lifecycle-rules.md) for the full per-state gate table.
- `requires:` is the action→action dependency edge. It drives `acyclic-deps` and `stable-blockers`. Use the pipe-syntax wikilink convention: `"[[module.entity.action|module::entity::action]]"`.
- `superseded_by:` is required (non-null) when `lifecycle == superseded`. Must point to an existing action id.

## Body sections

The body has six sections in fixed order: `## Purpose` · `## Inputs` · `## Outputs` · `## Entities` · `## Behavior` · `## Errors`. Each has a consistent shape across descriptors:

- **`## Purpose`** — operator-readable role of the action in the system. Back-sourcing is **prosaic**: wikilinks weave into the sentence that makes the claim, using pipe-syntax display text where it reads better. No trailing `Back-source: [[x]], [[y]].` lines, no bare `[[link]]` at the end of behavior steps.
- **`## Inputs`** — 4-column table: `| Parameter | Type | Required | Description |`. When all params share a property (e.g. every parameter is optional, or every parameter is required), state it in a lead-in sentence above the table and you may omit the column.
- **`## Outputs`** — a **logical contract**, not a wire shape. Three sub-patterns by what the action returns:
  - **Whole entity (or array of it)** → 1-line reference to the entity document, no inline table. Form: `An array of [[platform.action|platform::action]] entities.` The entity document's `## Fields` table is the canonical declaration of the field shape; duplicating it here would drift.
  - **Subset of an entity** (e.g. the action returns only `{id, name}` from a 10-field entity) → inline table listing the returned fields, drawn from the entity's canonical types.
  - **Derived / synthesized / multi-entity** (e.g. the action reads A, joins B and C, returns a derived shape) → inline table declaring the actual returned shape.
- **`## Entities`** — one sub-section per entity the action touches, headed `### [[module.entity|module::entity]]`, then an `**Effect:**` line (`create` · `read` · `read-whole` · `update` · `delete` · `append` · `replace`), then a field-touch table. Field names in tables are wrapped in backticks (`` `field_name` ``) to neutralize intraword underscore italics in CommonMark renderers. These sub-sections drive `entity-coherence` and feed the entity document's `## Fields` + `## Touched by` tables during consolidation. The field-touch rows are the authoritative declarations of which fields this action reads or writes. Use `read-whole` when the action returns the entire entity (or an array of entities); the field-touch table then enumerates only filters and keys, not the full returned shape. Plain `read` is reserved for partial projections that genuinely surface only a subset of fields.
- **`## Behavior`** — numbered steps. Each step that makes a sourceable claim weaves its wikilinks into the sentence (prosaic back-sourcing), not as trailing references.
- **`## Errors`** — bullet list of error codes with operator-facing messages.

## Pure-contract scope

The descriptor specifies what the action does, what it consumes, what it returns, which entities it touches. **How the action is exposed to callers** (HTTP route, CLI command, MCP tool, workflow node, agent tool) lives in surface-binding artifacts owned by their respective modules (e.g. URE Functions, AI Agents Tools, Devices Edge) and is out of scope for this descriptor.

Storage details, runtime engine, boot mechanics, persistence layer — also out of scope. The descriptor models the contract; how the contract is realized is somebody else's artifact.

## Verb & touch conventions

The action verb (last id segment) and the per-field touch verbs follow a **cross-module taxonomy** — source of truth [[adr-plt-action-verb-conventions]], operationalized in [`interview-prompts-action.md`](interview-prompts-action.md) under *Action verb taxonomy*. In brief: reads are `list`/`get` (+ plural sub-collection verbs, always paginated) with per-field touch `read`/`read-whole`; mutations split by nature (`create`/`edit`/`deploy`/`move`/`rollback`/`enable`/`disable`/`delete`), never an overloaded `update`.

## Wikilink convention

Action and entity references use **pipe-syntax** wikilinks: `[[platform.action.find|platform::action::find]]`. The on-disk file (dotted name) resolves cleanly while the displayed text is the canonical id (colon form). Works in any CommonMark-compatible renderer without frontmatter aliases or plugin dependencies. Apply uniformly:

- Action ref: `[[module.entity.action|module::entity::action]]`
- Entity ref: `[[module.entity|module::entity]]`

## Diff convention for proposals

When proposing changes to an existing file inside the authoring conversation, **show diffs in unified ` ```diff ` blocks** with leading `-` / `+` / ` ` markers, rather than full before/after text blobs. Diffs are far easier for the operator to scan and approve at speed. Apply uniformly across every subcommand. Full text is reserved for genuinely new files.
