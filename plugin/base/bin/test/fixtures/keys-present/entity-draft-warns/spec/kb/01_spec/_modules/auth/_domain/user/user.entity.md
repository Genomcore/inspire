---
id: auth.user
module: auth
entity: user
lifecycle: draft
---

## Purpose
The user account entity, grounded in [auth-user-management](../../_features/user-management.feature.md).

## Rationale
Identity model rationale, per [adr-auth-01-identity-model](../../../../_adr/auth-01-identity-model.adr.md).

## Invariants
Email is unique per organisation and nothing else holds.

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
| [auth::user::create](user.create.action.md) | write | Inserts the row. |
