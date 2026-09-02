---
id: auth::user::list
module: auth
entity: user
action: list
lifecycle: stable
requires: []
superseded_by: null
---

## Purpose
The list verb on the account, per [[auth-user-management]].

## Inputs

| Parameter | Type | Required | Description         |
|-----------|------|----------|---------------------|
| `id`      | uuid | yes      | The account to act on. |

## Outputs

| Field | Type | Description        |
|-------|------|--------------------|
| `id`  | uuid | The account id.    |

## Entities

### [[auth.user|auth::user]]
**As input:** key · **Effect:** read

| Field | Touch | Type | Mapping | Notes |
|-------|-------|------|---------|-------|
| `id`  | read  | uuid | —       |       |

## Preconditions
- `P1` — exists(auth.user) — The row must already exist.

## Behavior
1. `B1` — Act on the row named by the identifier, per [[auth-user-management]].

## Postconditions
- `Q1` — returns(id) — The caller receives the identifier.

## Errors
- `none`
