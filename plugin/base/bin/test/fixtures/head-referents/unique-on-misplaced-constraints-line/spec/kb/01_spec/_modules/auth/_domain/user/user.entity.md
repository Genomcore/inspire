---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
The user account entity, grounded in [auth-user-management](../../_features/user-management.feature.md).

## Rationale
Identity model rationale, per [adr-auth-01-identity-model](../../../../_adr/auth-01-identity-model.adr.md).

## Invariants
None beyond Fields constraints.

## Fields

| Field   | Type  | Notes                          |
|---------|-------|--------------------------------|
| `id`    | uuid  | Primary key.                   |
| `email` | email | The canonical identity handle. |

### id
Constraints: `nonnull, unique, immutable`

### email
The handle a person signs in with, per [adr-auth-01-identity-model](../../../../_adr/auth-01-identity-model.adr.md).

Constraints: `nonnull, unique, pattern(/.+@.+/)`

## Touched by

| Action | Touch | Notes |
|---|---|---|
| [auth::user::create](user.create.action.md) | write | Inserts the row. |
