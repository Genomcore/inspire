---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: draft
requires:
  - "[[auth.user.create|auth::user::create]]"
superseded_by: null
---

## Purpose
Self-referencing action.

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
**As input:** shape · **Effect:** create

| Field | Touch   | Type  | Mapping       | Notes |
|-------|---------|-------|---------------|-------|
| `id`  | written | uuid  | `uuid()`      |       |

## Behavior
1. Persist.

## Errors
- `none`
