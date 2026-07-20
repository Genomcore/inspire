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
Reads `last_seen` but no action writes it — should fail.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id`      | uuid | yes      | User id.    |

## Outputs

| Field       | Type      | Description       |
|-------------|-----------|-------------------|
| `id`        | uuid      | User id.          |
| `email`     | email     | Login.            |
| `last_seen` | timestamp | Last seen.        |

## Entities

### [[auth.user|auth::user]]
**As input:** id · **Effect:** read

| Field       | Touch | Type      | Mapping | Notes               |
|-------------|-------|-----------|---------|---------------------|
| `id`        | read  | uuid      | —       |                     |
| `email`     | read  | email     | —       |                     |
| `last_seen` | read  | timestamp | —       | nobody writes this! |

## Behavior
1. Fetch the user row.

## Errors
- `not_found`
