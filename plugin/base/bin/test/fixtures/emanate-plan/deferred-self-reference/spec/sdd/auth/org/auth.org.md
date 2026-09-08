---
id: auth.org
module: auth
entity: org
lifecycle: accepted
---

## Purpose
The organisation a principal belongs to, per [[auth-user-management]].

## Rationale
Organisations exist as their own object because [[adr-auth-01-identity-model]]
scopes every principal to one.

## Invariants
None beyond Fields constraints.

## Fields

| Field            | Type   | Notes                        |
|------------------|--------|------------------------------|
| `id`             | uuid   | Primary key.                 |
| `slug`           | string | The public handle.           |
| `parent_org_id`  | uuid   | The organisation above this one. |

### id
Constraints: `nonnull, unique, immutable`

### slug
Constraints: `nonnull, len(3, 64)`

### parent_org_id
Constraints: `references(auth.org)`

The self reference every hierarchy carries. Nullable, because a root
organisation sits under nothing.

## Touched by

| Action | Touch | Notes |
|--------|-------|-------|
