---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
The account record a principal signs in with, described in [[auth-user-management]].

## Rationale
The account is a discrete object because [[adr-auth-01-identity-model]] scopes
principals to an organisation rather than to the platform.

## Invariants
- `I1` — unique(org_id, email) — Email is unique per organisation, never globally.
- `I2` — A suspended account keeps every row it wrote; suspension changes what may be read.

## Fields

| Field        | Type      | Notes                          |
|--------------|-----------|--------------------------------|
| `id`         | uuid      | Primary key.                   |
| `org_id`     | uuid      | The owning organisation.       |
| `email`      | email     | The canonical identity handle. |
| `status`     | moneybags | Where the account sits.        |
| `created_at` | timestamp | The audit-timeline anchor.     |

### id
Constraints: `nonnull, unique, immutable`

### org_id
Constraints: `nonnull, immutable, references(auth.org)`

Grounded in the scoping rule of [[adr-auth-01-identity-model]].

### email
Constraints: `nonnull, pattern(/^[a-z]{3,8}@.+$/)`

Deliberately permissive, deferring to [[auth-email-validation]].

### status
Constraints: `nonnull, default(active)`

### created_at
Constraints: `nonnull, immutable, default(now)`

## Touched by

| Action                                   | Touch | Notes            |
|------------------------------------------|-------|------------------|
| [[auth.user.create\|auth::user::create]] | write | Inserts the row. |
| [[auth.user.get\|auth::user::get]]       | read  | Looks it up.     |
