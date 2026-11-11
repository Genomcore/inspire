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
Touches a `display_name` field that the entity doc has not declared.

## Inputs

| Parameter      | Type  | Required | Description |
|----------------|-------|----------|-------------|
| `email`        | email | yes      | Login.      |

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | New user id.|

## Entities

### [[auth.user|auth::user]]
**Effect:** create

| Field          | Touch   | Type  | Mapping              | Notes |
|----------------|---------|-------|----------------------|-------|
| `id`           | written | uuid  | `uuid()`             |       |
| `display_name` | written | string | `input.display_name` | Action declares this, entity doesn't list it. |

## Behavior
1. Persist.

## Errors
- `none`
