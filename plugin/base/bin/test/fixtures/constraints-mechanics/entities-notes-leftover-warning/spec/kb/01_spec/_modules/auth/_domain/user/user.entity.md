---
id: auth.user
module: auth
entity: user
lifecycle: draft
---

## Purpose
The user entity, grounded in [[auth-user-management]].

## Rationale
Rationale, per [[adr-auth-01-identity-model]].

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
