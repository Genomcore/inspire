---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: superseded
requires: []
superseded_by: "[auth::user::register](user.register.action.md)"
---

## Purpose
Create a user.

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | New user id.|

## Inputs

| Parameter | Type  | Required | Description |
|-----------|-------|----------|-------------|
| `email`   | email | yes      | Login.      |

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
