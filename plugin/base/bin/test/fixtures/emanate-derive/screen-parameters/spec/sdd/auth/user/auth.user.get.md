---
id: auth::user::get
module: auth
entity: user
action: get
lifecycle: accepted
requires: []
superseded_by: null
---

## Purpose
Read one account by its identifier, for the roster described in [[auth-user-management]].

## Inputs

| Parameter | Type | Required | Description          |
|-----------|------|----------|----------------------|
| `id`      | uuid | yes      | The account to read. |

## Outputs

An array of [[auth.user|auth::user]] entities.

## Entities

### [[auth.user|auth::user]]
**As input:** key · **Effect:** read

| Field | Touch | Type | Mapping | Notes |
|-------|-------|------|---------|-------|
| `id`  | read  | uuid | —       |       |

## Preconditions
- `P1` — exists(auth.user) — The row the identifier names must already exist.

## Behavior
1. `B1` — Look the row up by its identifier, per [[auth-user-management]].

## Postconditions
- `Q1` — unchanged(auth.org) — No organisation row is touched by a read.

## Errors
- `none`
