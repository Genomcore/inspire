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
- `I2` — A row that leaves `active` keeps its `email` and `org_id`, so the handle stays reserved to the organisation.
- `I3` — A `created_at` earlier than the row it belongs to is never written; the `status` a row starts in is the one it was created with.

## Fields

| Field        | Type      | Notes                          |
|--------------|-----------|--------------------------------|
| `id`         | uuid      | Primary key.                   |
| `org_id`     | uuid      | The owning organisation.       |
| `email`      | email     | The canonical identity handle. |
| `status`     | status    | Where the account sits.        |
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
| [[auth.user.list\|auth::user::list]]     | read  | Lists the roster. |
