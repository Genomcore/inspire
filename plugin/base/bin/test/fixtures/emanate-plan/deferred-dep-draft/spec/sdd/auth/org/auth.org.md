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

| Field           | Type   | Notes                             |
|-----------------|--------|-----------------------------------|
| `id`            | uuid   | Primary key.                      |
| `slug`          | string | The public handle.                |
| `owner_user_id` | uuid   | The account that currently owns it. |

### id
Constraints: `nonnull, unique, immutable`

### slug
Constraints: `nonnull, len(3, 64)`

### owner_user_id
Constraints: `references(auth.user)`

Nullable, and the back half of a mutual pair: an organisation exists before any
account does, so ownership is set once both rows are there.

## Touched by

| Action | Touch | Notes |
|--------|-------|-------|
