---
id: auth::password::hash
module: auth
entity: password
action: hash
lifecycle: draft
requires: []
superseded_by: null
---

## Purpose
Hash a password. Still in draft.

## Inputs

| Parameter  | Type     | Required | Description |
|------------|----------|----------|-------------|
| `password` | password | yes      | Plaintext.  |

## Outputs

| Field  | Type   | Description    |
|--------|--------|----------------|
| `hash` | string | Password hash. |

## Entities

### [[auth.password|auth::password]]
**As input:** shape · **Effect:** create

| Field  | Touch   | Type   | Mapping            | Notes |
|--------|---------|--------|--------------------|-------|
| `hash` | written | string | `bcrypt(password)` |       |

## Behavior
1. Hash.

## Errors
- `none`
