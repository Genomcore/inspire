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
None beyond Fields constraints.

## Fields

| Field      | Type   | Notes                          |
|------------|--------|--------------------------------|
| `id`       | uuid   | Primary key.                   |
| `email`    | email  | The canonical identity handle. |
| `handle`   | string | The public display handle.     |

### id
Constraints: `nonnull, unique, immutable`

### email
Constraints: `nonnull, pattern(/^[a-z]{3,8}@.+$/)`

### handle
Constraints: `nonnull, pattern(/^[a-z,._-]{2,32}$/), len(2, 32)`

## Touched by

| Action | Touch | Notes |
|---|---|---|
| [[auth.user.create|auth::user::create]] | write | Inserts the row. |
