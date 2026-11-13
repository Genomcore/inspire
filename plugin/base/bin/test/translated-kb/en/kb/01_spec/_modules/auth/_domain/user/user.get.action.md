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
Read one user account, per [adr-auth-sessions](../../_adr/auth-sessions.adr.md).

## ACT2: Inputs

| Parameter | Type | Required | Description          |
|-----------|------|----------|----------------------|
| `id`      | uuid | yes      | The account to read. |

## ACT3: Outputs
The whole [auth::user](user.entity.md) row.

## ACT4: Entities

### [auth::user](user.entity.md)
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
