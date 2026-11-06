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
Create a user account, per [[auth-user-management]].

## Inputs

| Parameter | Type  | Required | Description   |
|-----------|-------|----------|---------------|
| `email`   | email | yes      | Login handle. |

## Outputs

| Field | Type | Description  |
|-------|------|--------------|
| `id`  | uuid | New user id. |

## Entities

### [[auth.user|auth::user]]
**Effect:** create

| Field | Touch   | Type | Mapping  | Notes |
|-------|---------|------|----------|-------|
| `id`  | written | uuid | `uuid()` | Unique across rows. |

## Preconditions
None.

## Behavior
1. `B1` — Persist the row.

## Postconditions
- `Q1` — created(auth.user) — One row exists.
- `Q2` — unchanged(auth.user) — No audit event is emitted here.

## Errors
- `none`
