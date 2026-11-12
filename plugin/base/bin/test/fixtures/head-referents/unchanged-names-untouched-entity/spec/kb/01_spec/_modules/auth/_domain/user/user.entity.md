---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
The user entity, grounded in [auth-user-management](../../_features/user-management.feature.md).

## Rationale
Rationale, per [adr-auth-01-identity-model](../../../../_adr/auth-01-identity-model.adr.md).

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |

### id
Constraints: `nonnull, unique, immutable`

## Touched by

| Action | Touch | Notes |
|---|---|---|
