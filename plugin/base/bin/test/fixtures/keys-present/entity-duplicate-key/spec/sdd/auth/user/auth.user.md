---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
The user account entity, grounded in [[auth-user-management]].

## Rationale
Identity model rationale, per [[adr-auth-01-identity-model]].

## Invariants
- `I1` — unique(org_id, email) — Email is unique per organisation.
- `I1` — A suspended account keeps every row it wrote.

## Fields

| Field    | Type  | Notes                          |
|----------|-------|--------------------------------|
| `id`     | uuid  | Primary key.                   |
| `org_id` | uuid  | The owning organisation.       |
| `email`  | email | The canonical identity handle. |

### id
Constraints: `nonnull, unique, immutable`

### org_id
Constraints: `nonnull, immutable`

### email
Constraints: `nonnull, pattern(/.+@.+/)`

## Touched by

| Action | Touch | Notes |
|---|---|---|
| [[auth.user.create|auth::user::create]] | write | Inserts the row. |
