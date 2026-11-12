---
id: auth.org
module: auth
entity: org
lifecycle: accepted
---

## Purpose
The organisation entity, grounded in [[auth-tenancy]].

## Rationale
Tenancy rationale, per [[adr-auth-03-tenancy]].

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
