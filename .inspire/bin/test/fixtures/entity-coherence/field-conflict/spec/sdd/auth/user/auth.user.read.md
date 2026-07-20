---
id: auth::user::read
module: auth
entity: user
action: read
lifecycle: draft
requires: []
superseded_by: null
---

## Purpose
Declares `id: integer` — conflicts with create.

## Inputs

| Parameter | Type    | Required | Description |
|-----------|---------|----------|-------------|
| `id`      | integer | yes      | User id.    |

## Outputs

| Field   | Type    | Description |
|---------|---------|-------------|
| `id`    | integer | User id.    |
| `email` | email   | Login.      |

## Entities

### [[auth.user|auth::user]]
**As input:** id · **Effect:** read

| Field   | Touch | Type    | Mapping | Notes                |
|---------|-------|---------|---------|----------------------|
| `id`    | read  | integer | —       | conflict with create |
| `email` | read  | email   | —       |                      |

## Behavior
1. Fetch.

## Errors
- `none`
