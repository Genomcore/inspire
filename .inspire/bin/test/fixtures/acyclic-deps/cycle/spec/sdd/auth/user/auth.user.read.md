---
id: auth::user::read
module: auth
entity: user
action: read
lifecycle: draft
requires:
  - "[[auth.user.create|auth::user::create]]"
superseded_by: null
---

## Purpose
Cycle test (read depends on create which depends on read).

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id`      | uuid | yes      | User id.    |

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | User id.    |

## Entities

### [[auth.user|auth::user]]
**As input:** id · **Effect:** read

| Field | Touch | Type | Mapping | Notes |
|-------|-------|------|---------|-------|
| `id`  | read  | uuid | —       |       |

## Behavior
1. Fetch.

## Errors
- `none`
