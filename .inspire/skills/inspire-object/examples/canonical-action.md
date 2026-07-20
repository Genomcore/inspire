## Canonical action descriptor — `auth::user::create`

A complete, annotated action descriptor. This is the shape every `create` action should mirror. Annotations are in HTML comments so they survive a copy-paste into a real `.inspire_kb/04_specs/auth/user/auth.user.create.md`.

---

```markdown
---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: accepted             # ← gated rules: field-conflict and unsourced apply from draft+.
requires:                       # ← action→action edges; checked by acyclic-deps + stable-blockers.
  - "[[auth.password.hash|auth::password::hash]]"
superseded_by: null             # ← required iff lifecycle == superseded.
---

## Purpose
Provision a new platform user account from an email + password pair. The [[auth-user-management|user-management subsystem]] is the single entrypoint for user creation — agents must not write the `auth::user` row directly. The identity model, scopes, and the auth-provider integration are grounded in [[adr-auth-01-identity-model]].

## Inputs

| Parameter  | Type     | Required | Description                                              |
|------------|----------|----------|----------------------------------------------------------|
| `email`    | email    | yes      | Account login email; canonical semantic type. Unique.    |
| `password` | password | yes      | Plaintext password; hashed before write.                 |

## Outputs

| Field | Type | Description                |
|-------|------|----------------------------|
| `id`  | uuid | The newly created user id. |

## Entities

### [[auth.user|auth::user]]    <!-- ← H3 with pipe-syntax wikilink. The entity id is the join key in entity-coherence. -->
**As input:** shape · **Effect:** create

| Field          | Touch   | Type      | Mapping                | Notes                                |
|----------------|---------|-----------|------------------------|--------------------------------------|
| `id`           | written | uuid      | `uuid()`               | PK; generated at write.              |
| `email`        | written | email     | `input.email`          | Unique across `auth::user` rows.     |
| `password`     | written | password  | `hash(input.password)` | Never stored plaintext.              |
| `created_at`   | written | timestamp | `now()`                | Set at insert; never updated.        |

## Behavior
1. Validate `email` against RFC 5321 and the project's allow-list rules described in [[auth-email-validation|the email-validation rules]].
2. Hash `password` via [[auth.password.hash|auth::password::hash]] using bcrypt at the cost defined in [[adr-auth-02-password-hashing]].
3. INSERT INTO `auth_user (id, email, password, created_at)`. The DB unique constraint on `email` is the conflict-detection mechanism — if it fires, fall through to the `email_exists` error.
4. Audit event emission is out of scope for this action; the public-facing wrapper [[auth.user.signup|auth::user::signup]] layers that side-effect on top.

## Errors
- `email_exists` — operator-facing message: "An account already exists with that email."
- `password_too_weak` — operator-facing message: "Password must be at least 12 characters and contain mixed case and digits."
- `email_invalid` — operator-facing message: "Email address is not valid."
```

---

## What this descriptor does NOT have

Things you might expect but that don't belong in the descriptor:

- **No H1 heading.** The id lives in frontmatter and is reconstructible from the file path, so a leading `# auth::user::create` heading would be the third repetition of the same information. The body starts directly with `## Purpose`.
- **No surface declarations.** No HTTP routes, no CLI command forms, no MCP tool names. The descriptor describes the contract; how this action is exposed lives in surface-binding artifacts owned by their respective modules (URE Functions, AI Agents MCP, Devices Edge) — not in the SDD layer.
- **No trailing `Back-source:` lines.** Back-sourcing is prosaic: wikilinks weave into the sentence that makes the claim. No paratextual trailing references, no bare `[[link]]` at the end of behavior steps.
- **No implementation language.** "Use Postgres", "implement in Node.js", "via Drizzle ORM" — these are downstream concerns. The descriptor specifies *what*, not *how*.
- **No length / regex constraints.** `email` is the type; the email-validation rules live in the [[auth-email-validation|email-validation feature]] the prose links to.
- **No related-entity fields in the `auth::user` table.** This action only writes `auth::user` rows. Audit event logging is a separate Entity in the orchestrator action [[auth.user.signup|auth::user::signup]].
