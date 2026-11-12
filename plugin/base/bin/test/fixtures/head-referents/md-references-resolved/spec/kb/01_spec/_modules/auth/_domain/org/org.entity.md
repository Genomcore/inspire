---
id: auth.org
module: auth
entity: org
lifecycle: accepted
---

## Purpose
The organisation entity, grounded in [auth-tenancy](../../_features/tenancy.feature.md).

## Rationale
Tenancy rationale, per [adr-auth-03-tenancy](../../../../_adr/auth-03-tenancy.adr.md).

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
