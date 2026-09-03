---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: accepted
requires: []
superseded_by: null
---

## Purpose
Create a user account, per [[auth-user-management]].

## Inputs

| Parameter | Type  | Required | Description   |
|-----------|-------|----------|---------------|
| `email`   | email | yes      | Login handle. |

### email
Constraints: `nonnull, len(3, 254)`

## Outputs

| Field | Type | Description  |
|-------|------|--------------|
| `id`  | uuid | New user id. |

## Entities

### [[auth.user|auth::user]]
**Effect:** create

| Field    | Touch   | Type  | Mapping         | Notes |
|----------|---------|-------|-----------------|-------|
| `id`     | written | uuid  | `uuid()`        |       |
| `org_id` | written | uuid  | `current_org`   |       |
| `email`  | written | email | `input.email`   |       |

## Preconditions
- `P1` — actor(admin) — Only an administrator provisions accounts.
- `P2` — absent(auth.user) — No account may hold that email already.

## Behavior
1. `B1` — Validate the email.
2. `B2` — Persist the row.

## Postconditions
- `Q1` — created(auth.user) — Exactly one row exists.
- `Q2` — returns(id) — The caller receives the identifier.

## Errors
- `email_exists` — unique(email) — operator-facing message: "Taken."
- `org_conflict` — unique(org_id) — operator-facing message: "Conflict."
