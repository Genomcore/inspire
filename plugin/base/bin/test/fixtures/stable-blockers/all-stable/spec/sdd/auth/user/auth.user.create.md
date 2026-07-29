---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: stable
requires:
  - "[[auth.password.hash|auth::password::hash]]"
superseded_by: null
---

## Purpose
Stable action with stable dep — should pass.

## Inputs

| Parameter  | Type     | Required | Description |
|------------|----------|----------|-------------|
| `email`    | email    | yes      | Login.      |
| `password` | password | yes      | Plaintext.  |

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
