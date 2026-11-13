---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: superseded
requires: []
superseded_by: "[auth::user](user.entity.md)"
---

## Purpose
superseded_by points to an entity, not an action — should fail.

## Inputs

| Parameter | Type  | Required | Description |
|-----------|-------|----------|-------------|
| `email`   | email | yes      | Login.      |

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | New user id.|

## Entities

### [auth::user](user.entity.md)
**Effect:** create

| Field | Touch   | Type | Mapping  | Notes |
|-------|---------|------|----------|-------|
| `id`  | written | uuid | `uuid()` |       |

## Behavior
1. Persist.

## Errors
- `none`
