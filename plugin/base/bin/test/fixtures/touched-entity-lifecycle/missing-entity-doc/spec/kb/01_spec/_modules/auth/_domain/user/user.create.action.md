---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: stable
requires: []
superseded_by: null
---

## Purpose
Stable action touching an entity whose file is no entity document (it has no `.entity.md` extension) — should fail.

## Inputs

| Parameter  | Type     | Required | Description |
|------------|----------|----------|-------------|
| `email`    | email    | yes      | Login.      |

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | New user id.|

## Entities

### [auth::user](user.md)
**As input:** shape · **Effect:** create

| Field | Touch   | Type  | Mapping       | Notes |
|-------|---------|-------|---------------|-------|
| `id`  | written | uuid  | `uuid()`      |       |

## Behavior
1. Persist.

## Errors
- `none`
