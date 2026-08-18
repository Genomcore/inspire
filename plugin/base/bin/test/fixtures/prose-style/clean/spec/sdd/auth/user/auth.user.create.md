---
id: auth::user::create
lifecycle: accepted
---

# auth::user::create

## Purpose

The action creates a user for the tenant, and it hashes the password before the write.

## Inputs

| Parameter | Type | Required | Description |
|---|---|---|---|
| `email` | email | yes | The login email of the account. |

## Outputs

| Field | Type | Description |
|---|---|---|
| `id` | uuid | The id of the new user. |

## Entities

### [[auth.user|auth::user]]

**As input:** no · **Effect:** create

| Field | Touch | Type | Mapping | Notes |
|---|---|---|---|---|
| `id` | written | uuid | `uuid()` | |

## Behavior

The action hashes the password with [[auth.password.hash|auth::password::hash]], then it writes the row.

## Errors

- `none`
