---
id: auth::user::get
module: auth
entity: user
action: get
lifecycle: accepted
requires: []
superseded_by: null
---

## ACT1: Purpose
Read one user account, per [[adr-auth-sessions]].

## ACT2: Inputs

| Parameter | Type | Required | Description          |
|-----------|------|----------|----------------------|
| `id`      | uuid | yes      | The account to read. |

## ACT3: Outputs
The whole [[auth.user|auth::user]] row.

## ACT4: Entities

### [[auth.user|auth::user]]
**Effect:** read

| Field    | Touch | Type  | Mapping | Notes |
|----------|-------|-------|---------|-------|
| `id`     | read  | uuid  | `id`    |       |
| `org_id` | read  | uuid  |         |       |
| `email`  | read  | email |         |       |

## ACT5: Preconditions
None.

## ACT6: Behavior
1. `B1` — Load the row.

## ACT7: Postconditions
None.

## ACT8: Errors
- `not_found` — operator-facing message: "Unknown account."
