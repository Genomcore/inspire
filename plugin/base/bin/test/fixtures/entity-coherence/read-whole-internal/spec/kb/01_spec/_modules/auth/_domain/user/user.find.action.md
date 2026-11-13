---
id: auth::user::find
module: auth
entity: user
action: find
lifecycle: draft
requires: []
superseded_by: null
---

## Purpose
Looks up a user by id.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id`      | uuid | yes      | User id.    |

## Outputs
The matching [auth::user](user.entity.md) entity.

## Entities

### [auth::user](user.entity.md)
**As input:** id · **Effect:** read-whole

| Field | Touch | Type | Mapping    | Notes        |
|-------|-------|------|------------|--------------|
| `id`  | read  | uuid | `input.id` | Lookup key.  |

## Behavior
1. Fetch.

## Errors
- `none`
