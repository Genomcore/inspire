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
