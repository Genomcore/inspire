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

| Field            | Type      | Notes                                    |
|------------------|-----------|------------------------------------------|
| `id`             | uuid      | Primary key.                             |
| `org_id`         | uuid      | The owning organisation.                 |
| `billing_org_id` | uuid      | Who pays, when that is not the owner.    |
| `manager_id`     | uuid      | The account this one reports to.         |
| `email`          | email     | The canonical identity handle.           |
| `created_at`     | timestamp | The audit-timeline anchor.               |

### id
Constraints: `nonnull, unique, immutable`

### org_id
Constraints: `nonnull, immutable, references(auth.org)`

Grounded in the scoping rule of [[adr-auth-01-identity-model]].

### billing_org_id
Constraints: `references(auth.org)`

A second edge to the same target, and a nullable one: the pair must group into a
single `requires` entry, and that entry must stay structural because `org_id` is.

### manager_id
Constraints: `references(auth.user)`

The self reference every real vault carries. Nullable by construction — a root
account reports to nobody — so the edge is deferred.

### email
Constraints: `nonnull, pattern(/^[a-z]{3,8}@.+$/)`

Deliberately permissive, deferring to [[auth-email-validation]].

### created_at
Constraints: `nonnull, immutable, default(now)`

## Touched by

| Action                                   | Touch | Notes            |
|------------------------------------------|-------|------------------|
| [[auth.user.create\|auth::user::create]] | write | Inserts the row. |
