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
Creates a new user row.

## Inputs

| Parameter  | Type   | Required | Description |
|------------|--------|----------|-------------|
| `email`    | email  | yes      | Login.      |
| `password` | string | yes      | Cleartext.  |

## Entities

### [[auth.user|auth::user]]
**As input:** shape · **Effect:** create

| Field           | Touch   | Type      | Mapping                  | Notes |
|-----------------|---------|-----------|--------------------------|-------|
| `id`            | written | uuid      | `uuid()`                 |       |
| `email`         | written | email     | `input.email`            |       |
| `password_hash` | written | string    | `hash(input.password)`   |       |
| `created_at`    | written | timestamp | `now()`                  |       |

## Behavior
1. Persist row.

## Errors
- `none`
