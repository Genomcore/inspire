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
Reads only id and email.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id`      | uuid | yes      | User id.    |

## Outputs

| Field   | Type  | Description |
|---------|-------|-------------|
| `id`    | uuid  | User id.    |
| `email` | email | Login.      |

## Entities

### [[auth.user|auth::user]]
**As input:** id · **Effect:** read

| Field   | Touch | Type  | Mapping | Notes |
|---------|-------|-------|---------|-------|
| `id`    | read  | uuid  | —       |       |
| `email` | read  | email | —       |       |

## Behavior
1. Fetch.

## Errors
- `none`
