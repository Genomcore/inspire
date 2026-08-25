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

## Outputs

| Field | Type | Description  |
|-------|------|--------------|
| `id`  | uuid | New user id. |

## Entities

### [[auth.user|auth::user]]
**Effect:** create

| Field   | Touch   | Type  | Mapping       | Notes |
|---------|---------|-------|---------------|-------|
| `id`    | written | uuid  | `uuid()`      |       |
| `email` | written | email | `input.email` |       |

## Preconditions
- `P1` — actor(admin — Only an administrator provisions accounts.

## Behavior
1. `B1` — Validate the email.
2. `B2` — Persist the row.

## Postconditions
- `Q1` — created(auth.user) — Exactly one row exists.

## Errors
- `not_allowed` — actor(admin) — operator-facing message: "Forbidden."
