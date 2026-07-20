# Canonical entity document — `auth::user`

A complete, annotated entity document. This is the shape every entity doc should mirror — operator-authored `## Purpose` + `## Rationale` + `## Invariants` carry the design discipline; `## Fields` is the field shape (largely emergent from the actions that touch it, but every row exists because a design decision motivated it); per-field H3s opt in only when a field needs more than the Notes column; `## Touched by` is auto-populated by consolidation.

This is the entity document the canonical action descriptors (`auth::user::create`, `auth::user::find`, `auth::user::signup`) all touch. Annotations live in HTML comments so they survive a copy-paste into a real `.inspire_kb/04_domain/auth/user/auth.user.md`.

---

```markdown
---
id: auth.user
module: auth
entity: user
lifecycle: accepted             # ← symmetric with action lifecycle; promotion gating lands in Phase 3.5.
---

## Purpose
The `auth::user` entity is the platform's single source of truth for a user account — the row that represents an authenticated principal in the [[auth-user-management|user-management subsystem]]. Every authenticated session, every audit-event actor reference, and every permission-set binding ultimately resolves back to a row in this entity.

## Rationale
The entity exists as a discrete object because the identity model defined in [[adr-auth-01-identity-model]] mandates exactly one user-account record per `{scope, email}` tuple — the auth subsystem cannot delegate that uniqueness invariant to downstream consumers. The field shape is the minimum needed for the auth-provider integration plus the platform's local metadata: `email` is the canonical identity handle described in [[auth-identity-model|the identity-model feature]], `password_hash` carries credential material whose algorithm is a system-wide setting (see field-level rationale below), and `created_at` anchors the row to the platform audit timeline per [[adr-audit-01-centralized-logging]]. New fields land here only after `## Rationale` justifies them — the discussion-forcing discipline is what keeps the entity shape an act of design rather than a residue of action authoring.

## Invariants
- `email` is unique within the entity — no two rows may share the same email value. Enforced at the database level and required by the identity model in [[adr-auth-01-identity-model]].
- `password_hash` is write-only — no read action returns it. Reads exist only via `auth::password::verify` (constant-time comparison, never raw exposure).
- `created_at` is immutable after insert — no action updates it.

## Fields

| Field           | Type      | Notes                                                          |
|-----------------|-----------|----------------------------------------------------------------|
| `id`            | uuid      | Primary key. Generated at create-time.                         |
| `email`         | email     | Unique across rows. The canonical identity handle.             |
| `password_hash` | string    | Opaque credential blob; algorithm is system-wide (see below).  |
| `created_at`    | timestamp | Set at insert; never updated.                                  |
| `last_seen_at`  | timestamp | Updated by session activity; nullable until the first login.   |

### password_hash    <!-- ← per-field H3: motivated by a design call that the Notes column can't carry. -->
The column stores an opaque hashed credential, never plaintext. The hashing algorithm and cost parameters are a **system-wide** setting — not a per-row column — because rolling the algorithm is a platform migration, not a per-user choice. The decision and the migration mechanism are described in [[adr-auth-02-password-hashing]]. Verification goes through [[auth.password.verify|auth::password::verify]] (constant-time); the field is never returned by any read action.

### last_seen_at    <!-- ← per-field H3: nullability is non-obvious and worth a sentence. -->
Nullable until the first successful login. A freshly-created user that has never authenticated has `last_seen_at = null` rather than a synthetic value at the creation timestamp — distinguishing "never logged in" from "logged in once at creation" is load-bearing for the dormant-account reports described in [[auth-account-hygiene|the account-hygiene feature]].

<!-- ← `id` and `created_at` get no H3: self-evident from Notes column. -->

## Touched by

| Action                                                       | Touch  | Notes                                              |
|--------------------------------------------------------------|--------|----------------------------------------------------|
| [[auth.user.create|auth::user::create]]                      | write  | Inserts `id`, `email`, `password_hash`, `created_at`. |
| [[auth.user.find|auth::user::find]]                          | read   | Looks up by `id` or `email`; returns full row.     |
| [[auth.user.signup|auth::user::signup]]                      | write  | Public-facing wrapper; delegates row insert to `create`. |
```

---

## What this example teaches

- **Four mandatory sections + opt-in per-field H3 + auto-populated Touched by.** Every entity doc has `## Purpose` → `## Rationale` → `## Invariants` → `## Fields` → (optional per-field H3 sub-sections, in field-table order, placed immediately under the table) → `## Touched by`. Section order is fixed.

- **Purpose and Rationale are operator-authored prose, feature/ADR-grounded.** Wikilinks weave into the sentences that make the claims (prosaic back-sourcing). No trailing `Back-source:` lines. The Rationale is the **discussion-forcing function** — when an action introduces a new field, the agent surfaces the question and waits for the operator to update Rationale *before* the new row lands in `## Fields`.

- **Invariants can be short — or even one line.** When there's nothing to assert beyond what the Fields table already constrains, write `None beyond Fields constraints.` The section must be present; brevity is acceptable.

- **Fields is largely emergent, not arbitrary.** The row set comes from joining every action descriptor's `## Entities` declarations during consolidation. But each row exists because a design decision motivated it — adding one requires a Rationale update. The Notes column is short context; per-field H3 is for fields whose design notes don't fit a cell.

- **Per-field H3 is opt-in.** `password_hash` gets one because the algorithm-is-system-wide call is a design decision worth grounding in an ADR. `last_seen_at` gets one because nullability semantics are non-obvious. `id` and `created_at` don't — self-evident from the Notes column. Use H3s sparingly; the absence of one is a signal that the field's behavior is fully described by its Type + Notes.

- **Touched by uses pipe-syntax wikilinks and explicit touch verbs.** `[[auth.user.create|auth::user::create]]` resolves cleanly on disk (dotted) while displaying the canonical id (colon form). Touch values are `read` · `write` · `list` · `delete`. The section is **auto-populated** by consolidation — operators do not hand-edit it; the table is rewritten on every consolidation pass.

- **No `## Findings`, no `## Used by`.** Files state present truth only. Findings live in `review` output (git is the audit trail); the V2 `## Used by` is now `## Touched by` with explicit touch semantics.

- **Entity ids in frontmatter are 2-segment dotted** (`auth.user`), matching the on-disk filename. Action descriptors carry 3-segment dotted ids (`auth.user.create`); segment count is what tells the tooling the two object kinds apart.
