---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: accepted
requires: []
superseded_by: null
---

## ACT1: Purpose
Create a user account, per [[adr-auth-sessions]].

## ACT2: Inputs

| Parameter | Type  | Required | Description       |
|-----------|-------|----------|-------------------|
| `email`   | email | yes      | The login handle. |

### email
Constraints: `len(3, 254)`

## ACT3: Outputs

| Field | Type | Description      |
|-------|------|------------------|
| `id`  | uuid | The new user id. |

## ACT4: Entities

### [[auth.user|auth::user]]
**Effect:** create

| Field    | Touch   | Type  | Mapping       | Notes |
|----------|---------|-------|---------------|-------|
| `id`     | written | uuid  | `uuid()`      |       |
| `org_id` | written | uuid  | `current_org` |       |
| `email`  | written | email | `input.email` |       |
| `phone`  | written | text  | `null`        |       |

## ACT5: Preconditions
- `P1` — actor(admin) — Only an administrator provisions accounts.

## ACT6: Behavior
1. `B1` — Validate the email.
2. `B2` — Persist the row.

## ACT7: Postconditions
- `Q1` — created(auth.user) — Exactly one row exists.
- `Q2` — returns(id) — The caller receives the identifier.

## ACT8: Errors
- `email_exists` — unique(email) — operator-facing message: "Taken."
- `email_exists` — unique(org_id) — operator-facing message: "Conflict."
