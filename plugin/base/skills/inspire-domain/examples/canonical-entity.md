# Canonical entity document — `auth::user`

A complete, annotated entity document. This is the shape every entity doc should mirror — operator-authored `## Purpose` + `## Rationale` + `## Invariants` carry the design discipline; `## Fields` is the field shape (largely emergent from the actions that touch it, but every row exists because a design decision motivated it); per-field H3s carry each field's constraints and, where it needs one, its rationale; `## Touched by` is auto-populated by consolidation.

This is the entity document the canonical action descriptors (`auth::user::create`, `auth::user::find`, `auth::user::signup`) all touch. Annotations live in HTML comments so they survive a copy-paste into a real `inspire_kb/04_domain/auth/user/auth.user.md`.

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
The identity model in [[adr-auth-01-identity-model]] mandates exactly one user-account record per `{scope, email}` tuple, so the entity exists as a discrete object. The auth subsystem must not delegate that uniqueness invariant to a downstream consumer.

The field shape carries the minimum the auth-provider integration needs, plus the platform's own metadata. `email` is the canonical identity handle that [[auth-identity-model|the identity-model feature]] describes. `password_hash` carries credential material whose algorithm is a system-wide setting (see the field-level rationale below). `created_at` anchors the row to the platform audit timeline that [[adr-audit-01-centralized-logging]] defines.

A new field lands here only after `## Rationale` justifies it. The discussion-forcing discipline keeps the entity shape an act of design rather than a residue of action authoring.

## Invariants
- `I1` — immutable(email) — Changing an account's email is a new referent, not an edit: the [[adr-auth-01-identity-model|identity model]] makes the email half of the principal's identity, so a rename is a create plus a retire.
- `I2` — `password_hash` is write-only — no read action returns it. Reads exist only via `auth::password::verify` (constant-time comparison, never raw exposure).

<!-- ← `I1` carries a head because `immutable(email)` says it exactly; `I2` is prose-only, which is
     the normal case for the interesting ones, and derives a test-oracle claim rather than a
     store-oracle one. `email`'s uniqueness is NOT here: it is a single-field rule and lives on the
     field's own Constraints line, next to the field it constrains. -->

## Fields

| Field           | Type      | Notes                                                          |
|-----------------|-----------|----------------------------------------------------------------|
| `id`            | uuid      | Primary key.                                                   |
| `email`         | email     | The canonical identity handle.                                 |
| `password_hash` | string    | Opaque credential blob; algorithm is system-wide (see below).  |
| `created_at`    | timestamp | The platform audit-timeline anchor.                            |
| `last_seen_at`  | timestamp | Written by session activity; read by the dormancy reports.     |

### id
Constraints: `nonnull, unique, immutable`

### email
Constraints: `nonnull, unique, pattern(/.+@.+/)`

The pattern is deliberately permissive: the real rules are the deliverability and allow-list rules in [[auth-email-validation|the email-validation feature]], which change without the schema changing. What belongs here is the shape nothing downstream may violate.

### password_hash    <!-- ← the Constraints line, then the rationale the Notes column can't carry. -->
Constraints: `nonnull`

The column stores an opaque hashed credential, never plaintext. The hashing algorithm and cost parameters are a **system-wide** setting — not a per-row column — because rolling the algorithm is a platform migration, not a per-user choice. The decision and the migration mechanism are described in [[adr-auth-02-password-hashing]]. Verification goes through [[auth.password.verify|auth::password::verify]] (constant-time); the field is never returned by any read action.

### created_at
Constraints: `nonnull, immutable, default(now)`

### last_seen_at    <!-- ← no constraints at all: nullable by default, and that is the design. -->
Nullable until the first successful login, and deliberately carries no `nonnull`. A freshly-created user that has never authenticated has `last_seen_at = null` rather than a synthetic value at the creation timestamp — distinguishing "never logged in" from "logged in once at creation" is load-bearing for the dormant-account reports described in [[auth-account-hygiene|the account-hygiene feature]].

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

- **Invariants are keyed, and a head is optional.** `I1` carries `immutable(email)` because that head says it exactly; `I2` is prose-only, which is the normal case for the interesting invariants and derives a test-oracle claim instead of a store-oracle one. Keys are write-once: `I1` stays `I1`, deleting one leaves a gap, and nothing is renumbered. When there is nothing to assert beyond what the fields already constrain, write `None beyond Fields constraints.` — the section must be present; brevity is acceptable.

- **A single-field rule is not an invariant.** `email`'s uniqueness sits on `### email`'s Constraints line, not in `## Invariants`, because it constrains one field and belongs next to it. `## Invariants` is for the rules a single field cannot express — a tuple's uniqueness, a co-presence rule, referential integrity — and for the ones no head captures at all.

- **Fields is largely emergent, not arbitrary.** The row set comes from joining every action descriptor's `## Entities` declarations during consolidation. But each row exists because a design decision motivated it — adding one requires a Rationale update. The Notes column says what a field *means* to a reader; the constraints say what may not be violated, and the two never restate each other. "Unique across rows" in Notes next to `unique` on the line is two spellings of one fact.

- **Per-field H3 is mandatory for a constrained field, opt-in otherwise.** `id`, `email`, `password_hash` and `created_at` all have constraints, so all four carry an H3 — `id` and `created_at` say nothing beyond their Constraints line, and that is a complete H3. `password_hash` adds rationale because the algorithm-is-system-wide call is worth grounding in an ADR. `last_seen_at` carries no constraints at all and gets an H3 anyway, because *deliberate* nullability is a design statement worth making out loud — fields are nullable by default, so the absence of `nonnull` is quiet, and quiet is exactly what needs a sentence here.

- **Touched by uses pipe-syntax wikilinks and explicit touch verbs.** `[[auth.user.create|auth::user::create]]` resolves cleanly on disk (dotted) while displaying the canonical id (colon form). Touch values are `read` · `write` · `list` · `delete`. The section is **auto-populated** by consolidation — operators do not hand-edit it; the table is rewritten on every consolidation pass.

- **No `## Findings`, no `## Used by`.** Files state present truth only. Findings live in `review` output (git is the audit trail); the V2 `## Used by` is now `## Touched by` with explicit touch semantics.

- **Entity ids in frontmatter are 2-segment dotted** (`auth.user`), matching the on-disk filename. Action descriptors carry 3-segment dotted ids (`auth.user.create`); segment count is what tells the tooling the two object kinds apart.
