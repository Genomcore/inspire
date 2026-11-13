---
id: auth::user::create
lifecycle: stable
requires: []
---

## Purpose
Create a user, per [the user-management feature](../../_features/user-management.feature.md).

## Inputs
| Parameter | Type | Required | Description |
|---|---|---|---|
| `email` | email | yes | The address. |

## Outputs
An [auth::user](user.entity.md) entity.

## Entities
### [auth::user](user.entity.md)
**Effect:** create
| Field | Touch | Type | Mapping | Notes |
|---|---|---|---|---|
| `email` | written | email | `input.email` | The address. |

## Behavior
1. Persist the row, per [the feature](../../_features/user-management.feature.md).

## Errors
- `email_exists` — operator-facing message: "An account already exists with that email."
- `invalid_email` — operator-facing message: "That address is not valid."
