---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: superseded
requires:
  - "[[auth.user.persist|auth::user::persist]]"
superseded_by: "[[auth.user.persist|auth::user::persist]]"
---

## Purpose
Both links name an existing action — should pass.

## Inputs

| Parameter | Type  | Required | Description |
|-----------|-------|----------|-------------|
| `email`   | email | yes      | Login.      |

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | New user id.|

## Entities

### [[auth.user|auth::user]]
**Effect:** create

| Field | Touch   | Type | Mapping  | Notes |
|-------|---------|------|----------|-------|
| `id`  | written | uuid | `uuid()` |       |

## Behavior
1. Persist.

## Errors
- `none`
