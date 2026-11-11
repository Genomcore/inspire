---
id: auth::user::create
lifecycle: accepted
requires: []
---

## Purpose
Create a user, per [[auth-user-management|the user-management feature]].

## Inputs
| Parameter | Type | Required | Description |
|---|---|---|---|
| `email` | email | yes | The address. |

## Outputs
An [[auth.user|auth::user]] entity.

## Entities
### [[auth.user|auth::user]]
**Effect:** create
| Field | Touch | Type | Mapping | Notes |
|---|---|---|---|---|
| `email` | written | email | `input.email` | The address. |

## Behavior
1. Persist the row, per [[auth-user-management|the feature]].

## Errors
- `email_exists` — operator-facing message: "An account already exists with that email."
- `invalid_email` — operator-facing message: "That address is not valid."
