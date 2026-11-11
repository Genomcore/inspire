---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: superseded
requires: []
superseded_by: "[[auth.user.persist|auth::user::persist]]"
---

## Purpose
superseded_by points to a non-existent target — should fail.

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
