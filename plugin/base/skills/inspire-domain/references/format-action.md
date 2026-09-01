# Action descriptor format

The format spec for action descriptors. SKILL.md owns the interview cadence and lifecycle; this file owns the on-disk shape.

An action descriptor lives at `inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md`. The full-dotted-id filename (e.g. `auth/user/auth.user.create.md`) disambiguates Obsidian tabs and Quick Switcher, where bare verb filenames like `create.md` recur across entities. Dots — not `::` — because Windows forbids `:` in filenames.

A ready-to-copy template of this shape ships at [`../templates/action.md.template`](../templates/action.md.template).

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
Create a new platform user account from an email + password pair. The [[auth-user-management|user-management subsystem]] is the source of truth for identity; this verb is its admin-side account-provisioning entry point. Identity model, scopes, and the auth-provider integration are defined in [[adr-auth-01-identity-model]].

## Inputs

| Parameter  | Type     | Required | Description                              |
|------------|----------|----------|------------------------------------------|
| `email`    | email    | yes      | Account login email.                     |
| `password` | password | yes      | Plaintext password; hashed before write. |

### password
Constraints: `len(12, 128)`

The floor is the platform-wide minimum set by [[adr-auth-02-password-hashing]]; the ceiling exists so a pathological input cannot turn hashing into a denial of service.

## Outputs

| Field | Type | Description                |
|-------|------|----------------------------|
| `id`  | uuid | The newly created user id. |

## Entities

### [[auth.user|auth::user]]
**As input:** shape · **Effect:** create

| Field          | Touch   | Type      | Mapping       | Notes |
|----------------|---------|-----------|---------------|-------|
| `id`           | written | uuid      | `uuid()`      |       |
| `email`        | written | email     | `input.email` |       |
| `created_at`   | written | timestamp | `now()`       |       |

## Preconditions
- `P1` — actor(admin) — Only an administrator provisions accounts directly; the public path is [[auth.user.signup|auth::user::signup]].
- `P2` — absent(auth.user) — No account may already hold the submitted email, per the identity model in [[adr-auth-01-identity-model]].

## Behavior
1. `B1` — Validate the email format against the rules described in [[auth-user-management#email-constraints|the user-management email rules]].
2. `B2` — Hash the password using [[auth.password.hash|auth::password::hash]], following the auth-provider integration model in [[adr-auth-01-identity-model]].
3. `B3` — Persist a new user row with the hashed credential.

## Postconditions
- `Q1` — created(auth.user) — Exactly one row exists for the submitted email.
- `Q2` — returns(id) — The caller receives the new row's identifier.

## Errors
- `email_exists` — unique(email) — operator-facing message: "An account already exists with that email."
```

## Frontmatter

- **No H1 heading.** The id lives in frontmatter `id:` and is reconstructible from the file path, so a leading `# {id}` heading would be the third repetition of the same information. The body starts directly with `## Purpose`.
- `lifecycle` controls which quality_lib rules apply. See [`lifecycle-rules.md`](../../_references/lifecycle-rules.md) for the full per-state gate table.
- `requires:` is the action→action dependency edge. It drives `acyclic-deps` and `stable-blockers`. Use the pipe-syntax wikilink convention: `"[[module.entity.action|module::entity::action]]"`.
- `superseded_by:` is required (non-null) when `lifecycle == superseded`. Must point to an existing action id.

## Body sections

The body has eight sections in fixed order: `## Purpose` · `## Inputs` · `## Outputs` · `## Entities` · `## Preconditions` · `## Behavior` · `## Postconditions` · `## Errors`. The order is the Hoare reading of a contract — what must hold, what happens, what holds afterwards — and each section has a consistent shape across descriptors:

- **`## Purpose`** — operator-readable role of the action in the system. Back-sourcing is **prosaic**: wikilinks weave into the sentence that makes the claim, using pipe-syntax display text where it reads better. No trailing `Back-source: [[x]], [[y]].` lines, no bare `[[link]]` at the end of behavior steps.
- **`## Inputs`** — 4-column table: `| Parameter | Type | Required | Description |`. When all params share a property (e.g. every parameter is optional, or every parameter is required), state it in a lead-in sentence above the table and you may omit the column. A constrained parameter carries a `### {param}` H3 under the table whose first line is its `Constraints:` line — the same shape and the same closed vocabulary the entity format uses for fields, per [`keyed-heads.md`](../../_references/keyed-heads.md). A `Constraints:` line further down that H3 is read and checked too, and reported as misplaced (`OS-E8`) rather than ignored. The `Required` column stays the **only** home for required-ness, so `nonnull` never appears on an input's Constraints line.
- **`## Outputs`** — a **logical contract**, not a wire shape. Three sub-patterns by what the action returns:
  - **Whole entity (or array of it)** → 1-line reference to the entity document, no inline table. Form: `An array of [[platform.action|platform::action]] entities.` The entity document's `## Fields` table is the canonical declaration of the field shape; duplicating it here would drift.
  - **Subset of an entity** (e.g. the action returns only `{id, name}` from a 10-field entity) → inline table listing the returned fields, drawn from the entity's canonical types.
  - **Derived / synthesized / multi-entity** (e.g. the action reads A, joins B and C, returns a derived shape) → inline table declaring the actual returned shape.
- **`## Entities`** — one sub-section per entity the action touches, headed `### [[module.entity|module::entity]]`, then a metadata line — an optional leading `**As input:** X · ` (how the entity is identified for this action) followed by `**Effect:** Y` (`create` · `read` · `read-whole` · `update` · `delete` · `append` · `replace`) — then a field-touch table. Field names in tables are wrapped in backticks (`` `field_name` ``) to neutralize intraword underscore italics in CommonMark renderers. These sub-sections drive `entity-coherence` and feed the entity document's `## Fields` + `## Touched by` tables during consolidation. The field-touch rows are the authoritative declarations of which fields this action reads or writes. Use `read-whole` when the action returns the entire entity (or an array of entities); the field-touch table then enumerates only filters and keys, not the full returned shape. Plain `read` is reserved for partial projections that genuinely surface only a subset of fields. [`effect-touch-matrix.md`](effect-touch-matrix.md) is the authority for valid As-input × Effect combinations. [`type-mapping.md`](type-mapping.md) is the authority for the `Type` vocabulary and `Mapping` tokens, and the project's own types in `00_bootstrap/semantic-types.md`.
- **`## Preconditions`** — what must hold before the action may run, as keyed entries: `` - `P{n}` — {head} — {prose} ``. Heads come from vocabulary V3 of [`keyed-heads.md`](../../_references/keyed-heads.md) — `actor` · `exists` · `absent` · `state` — and are optional; a precondition no head captures is written prose-only. An action with genuinely no precondition says so: `None.` A precondition is a claim about the world, never about a caller's transport — an actor constraint belongs here precisely because it is true wherever the action runs.
- **`## Behavior`** — numbered steps, each **keyed**: `` 1. `B{n}` — {step prose} ``. The key is the step's identity and the markdown ordinal is presentation, so a deleted step leaves a gap rather than renumbering the survivors. Each step that makes a sourceable claim weaves its wikilinks into the sentence (prosaic back-sourcing), not as trailing references.
- **`## Postconditions`** — what holds once the action has succeeded, as keyed entries: `` - `Q{n}` — {head} — {prose} ``. Heads come from vocabulary V4 — `created` · `updated` · `deleted` · `unchanged` · `returns`. `unchanged({module}.{entity})` is worth stating deliberately: it is the regression guard that says an entity the action *could* have touched is left alone, and it is the one head that names an entity `## Entities` does not list. `None.` is the valid body for an action with no observable effect, which is rare enough to be worth a second look.
- **`## Errors`** — bullet list of error codes with operator-facing messages. An error may carry a head naming **what it reports the violation of** — `` - `email_exists` — unique(email) — operator-facing message: "…" `` — drawn from vocabulary V5. The head is what lets a uniqueness constraint on an entity field and the error an action raises for it be checked against each other rather than merely hoped to correspond. Each bullet becomes a test (`/inspire-code tdd` derives its list from the criteria ∪ this section ∪ the convention's always-present cases), so an error declared here and nowhere tested is a contract nobody checks. The observable response is **not** written here — see `## Pure-contract scope`; only a `**Wire deviation:**` note is.

## Keyed entries

Four of the eight sections carry **keyed** entries — `## Preconditions` (`P{n}`),
`## Behavior` (`B{n}`), `## Postconditions` (`Q{n}`) and `## Errors` (the error
code itself). The grammar, the closed head vocabularies, the derived claim ids
and the oracle split are all one shared contract, defined once in
[`keyed-heads.md`](../../_references/keyed-heads.md) and not restated here.

Two things about it are worth stating in this file, because they are what a
descriptor author feels:

- **Keys are write-once and never renumbered.** `B2` stays `B2` for the life of
  the step. Deleting it leaves `B1`, `B3` — a gap, which is the contract
  working. Renumbering would rename every survivor, and anything that cited a
  step would silently be citing a different one.
- **`## Behavior`'s first step carrying a `B{n}` key is the deterministic
  marker** that this descriptor is written in the current format. `## Behavior`
  is mandatory and non-empty in every descriptor ever written, so the marker can
  never be vacuous, and a strict reader can refuse a pre-keying descriptor
  per-artifact rather than guessing at the vault level.

Three coherence checks join across the sections, and each is a real defect when
it fails: a `P`/`Q` head naming an entity absent from `## Entities`;
`returns({field})` naming a field absent from `## Outputs`; and a written
`unique` field whose action declares no `unique(...)` error head covering it.

**What review blocks on.** The split is stated once, for both object kinds, in
[`keyed-heads.md`](../../_references/keyed-heads.md) § "Severity — two tiers".
What a keyed entry *says* — a head outside its vocabulary, a wrong arity, a
duplicate key, an unresolvable referent, a misplaced `Constraints:` line — ramps
with the descriptor's lifecycle: warning at `draft`, **error at `accepted` and
`stable`**, at pre-commit, at pre-PR and at `promote` alike. Whether the keyed
shape *is there at all* — no `B{n}` on the first step (`OS-A1`), no
`## Preconditions` (`OS-A3`), no `## Postconditions` (`OS-A4`) — is a **flat
warning at every lifecycle in 0.8**: those are precisely the shapes an upgrade
inherits, and a vault that upgrades cleanly may not go red on every descriptor
it already had. `derive` refuses an old-shape descriptor regardless, and the
presence classes ramp with the lifecycle in the release after 0.8.

## Pure-contract scope

The descriptor specifies what the action does, what it consumes, what it returns, which entities it touches. **How the action is exposed to callers** (HTTP route, CLI command, MCP tool, workflow node, agent tool) lives in surface-binding artifacts owned by their respective modules (e.g. URE Functions, AI Agents Tools, Devices Edge) and is out of scope for this descriptor.

**What a caller observes when a declared error fires is not out of scope, and it is not the descriptor's job either.** It comes from the project's resolved wire convention ([`_references/conventions/README.md`](../../_references/conventions/README.md), selected in `00_bootstrap/stack.md`): the descriptor names the logical error, the convention maps it to an observable response, once, for every action in the project. Restating a status code per descriptor would be the same duplication `## Outputs` already refuses for field shapes — and drift the same way.

The exception is a **deviation**, which belongs here because only this action knows about it. Declare it directly below `## Errors`:

```markdown
**Wire deviation:** `not_found` returns `403` instead of `404` — this endpoint is
reachable pre-authorization, and a `404` would let an unauthenticated caller enumerate
valid ids.
```

Silence means the convention holds. A deviation without a written reason is a finding, not a deviation.

Storage details, runtime engine, boot mechanics, persistence layer — also out of scope. The descriptor models the contract; how the contract is realized is somebody else's artifact.

## Verb & touch conventions

The action verb (last id segment) and the per-field touch verbs follow a **cross-module taxonomy** — source of truth [[adr-plt-action-verb-conventions]], operationalized in [`interview-prompts-action.md`](interview-prompts-action.md) under *Action verb taxonomy*. In brief: reads are `list`/`get` (+ plural sub-collection verbs, always paginated) with per-field touch `read`/`read-whole`; mutations split by nature (`create`/`edit`/`deploy`/`move`/`rollback`/`enable`/`disable`/`delete`), never an overloaded `update`.

## Wikilink convention

Action and entity references use **pipe-syntax** wikilinks: `[[platform.action.find|platform::action::find]]`. The on-disk file (dotted name) resolves cleanly while the displayed text is the canonical id (colon form). Works in any CommonMark-compatible renderer without frontmatter aliases or plugin dependencies. Apply uniformly:

- Action ref: `[[module.entity.action|module::entity::action]]`
- Entity ref: `[[module.entity|module::entity]]`

## Diff convention for proposals

When proposing changes to an existing file inside the authoring conversation, **show diffs in unified ` ```diff ` blocks** with leading `-` / `+` / ` ` markers, rather than full before/after text blobs. Diffs are far easier for the operator to scan and approve at speed. Apply uniformly across every subcommand. Full text is reserved for genuinely new files.
