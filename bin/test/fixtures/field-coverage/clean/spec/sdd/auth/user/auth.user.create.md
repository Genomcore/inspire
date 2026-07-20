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
Touches every field the entity declares.

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

| Field   | Touch   | Type  | Mapping       | Notes |
|---------|---------|-------|---------------|-------|
| `id`    | written | uuid  | `uuid()`      |       |
| `email` | written | email | `input.email` |       |

## Behavior
1. Persist.

## Errors
- `none`
