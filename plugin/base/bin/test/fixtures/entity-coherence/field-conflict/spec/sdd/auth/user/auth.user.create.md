---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: draft
requires: []
superseded_by: null
---

## Purpose
Declares `id: uuid`.

## Inputs

| Parameter | Type  | Required | Description |
|-----------|-------|----------|-------------|
| `email`   | email | yes      | Login.      |

## Outputs

| Field   | Type  | Description |
|---------|-------|-------------|
| `id`    | uuid  | New user id.|
| `email` | email | Login.      |

## Entities

### [[auth.user|auth::user]]
**As input:** shape · **Effect:** create

| Field   | Touch   | Type  | Mapping       | Notes |
|---------|---------|-------|---------------|-------|
| `id`    | written | uuid  | `uuid()`      |       |
| `email` | written | email | `input.email` |       |

## Behavior
1. Persist.

## Errors
- `none`
