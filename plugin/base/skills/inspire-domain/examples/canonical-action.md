## Canonical action descriptor — `auth::user::create`

A complete, annotated action descriptor. This is the shape every `create` action should mirror. Annotations are in HTML comments so they survive a copy-paste into a real `inspire_kb/04_domain/auth/user/auth.user.create.md`.

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
Provision a new user account for the platform from an email and password pair. The [[auth-user-management|user-management subsystem]] is the single entrypoint for user creation — agents must not write the `auth::user` row directly. [[adr-auth-01-identity-model]] grounds the identity model, the scopes and the auth-provider integration.

## Inputs

| Parameter  | Type     | Required | Description                                              |
|------------|----------|----------|----------------------------------------------------------|
| `email`    | email    | yes      | Account login email; canonical semantic type.            |
| `password` | password | yes      | Plaintext password; hashed before write.                 |

### password    <!-- ← per-input H3: the Constraints line, then why those bounds. -->
Constraints: `len(12, 128)`

The floor is the platform-wide minimum [[adr-auth-02-password-hashing]] sets; the ceiling exists so a pathological input cannot turn hashing into a denial of service. Note what is *not* here: `nonnull`. Required-ness is the `Required` column's, and saying it twice would let the two drift.

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
| `email`        | written | email     | `input.email`          | The identity handle.                 |
| `password`     | written | password  | `hash(input.password)` | Never stored plaintext.              |
| `created_at`   | written | timestamp | `now()`                | The audit-timeline anchor.           |

## Preconditions
- `P1` — actor(admin) — Only an administrator provisions accounts directly; the public path is [[auth.user.signup|auth::user::signup]], which layers allow-list and audit on top.
- `P2` — absent(auth.user) — No account may already hold the submitted email, since [[adr-auth-01-identity-model]] makes the email half of the principal's identity.

## Behavior
1. `B1` — Validate `email` against RFC 5321 and the project's allow-list rules described in [[auth-email-validation|the email-validation rules]].
2. `B2` — Hash `password` via [[auth.password.hash|auth::password::hash]] using bcrypt at the cost defined in [[adr-auth-02-password-hashing]].
3. `B3` — INSERT INTO `auth_user (id, email, password, created_at)`. The DB unique constraint on `email` is the conflict-detection mechanism — if it fires, fall through to the `email_exists` error.
4. `B4` — Audit event emission is out of scope for this action; the public-facing wrapper [[auth.user.signup|auth::user::signup]] layers that side-effect on top.

## Postconditions
- `Q1` — created(auth.user) — Exactly one row exists for the submitted email, with the hashed credential and the insert timestamp set.
- `Q2` — returns(id) — The caller receives the new row's identifier.
- `Q3` — unchanged(audit.event) — No audit event is emitted here. The wrapper owns that, and stating it turns "we did not mean to write that" into something the suite asserts.

## Errors
- `email_exists` — unique(email) — operator-facing message: "An account already exists with that email."
- `password_too_weak` — len(password) — operator-facing message: "Password must be at least 12 characters and contain mixed case and digits."
- `email_invalid` — pattern(email) — operator-facing message: "Email address is not valid."
- `forbidden` — actor(admin) — operator-facing message: "Only an administrator may create an account."
```

---

## What this descriptor does NOT have

Things you might expect but that don't belong in the descriptor:

- **No H1 heading.** The id lives in frontmatter and is reconstructible from the file path, so a leading `# auth::user::create` heading would be the third repetition of the same information. The body starts directly with `## Purpose`.
- **No surface in the actor claim.** `P1` says `actor(admin)`, not "admin console only". Who may act is true wherever the action runs; which surface exposes it is a downstream binding. A surface name appearing in a descriptor is nearly always a missing actor precondition or a missing module boundary.
- **No surface declarations.** No HTTP routes, no CLI command forms, no MCP tool names. The descriptor describes the contract; how this action is exposed lives in surface-binding artifacts owned by their respective modules (URE Functions, AI Agents MCP, Devices Edge) — not in the SDD layer.
- **No trailing `Back-source:` lines.** Back-sourcing is prosaic: wikilinks weave into the sentence that makes the claim. No paratextual trailing references, no bare `[[link]]` at the end of behavior steps.
- **No implementation language.** "Use Postgres", "implement in Node.js", "via Drizzle ORM" — these are downstream concerns. The descriptor specifies *what*, not *how*.
- **No validation *rules* — only bounds.** `password`'s Constraints line carries `len(12, 128)`, because a bound is a fact a validator can enforce and a test can assert. The email-validation *rules* — deliverability, allow-lists, normalization — stay in the [[auth-email-validation|email-validation feature]] the prose links to, because they change without the contract changing. The line between the two: if a downstream reader could act on it mechanically, it is a constraint; if acting on it needs judgment, it is a rule and it lives upstream.
- **No related-entity fields in the `auth::user` table.** This action only writes `auth::user` rows. Audit event logging is a separate Entity in the orchestrator action [[auth.user.signup|auth::user::signup]].
