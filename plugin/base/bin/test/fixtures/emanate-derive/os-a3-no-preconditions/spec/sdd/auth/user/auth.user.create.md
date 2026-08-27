---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: accepted
requires:
  - "[[auth.password.hash|auth::password::hash]]"
superseded_by: null
---

## Purpose
Provision an account from an email and an organisation, per [[adr-auth-01-identity-model]].

## Inputs

| Parameter | Type   | Required | Description                  |
|-----------|--------|----------|------------------------------|
| `email`   | email  | yes      | The login handle.            |
| `org_id`  | uuid   | yes      | The owning organisation.     |
| `status`  | status | no       | Where the account starts.    |

### email
Constraints: `pattern(/^[a-z]{3,8}@.+$/)`

The bound is the platform-wide one from [[adr-auth-01-identity-model]].

### org_id
Constraints: `references(auth.org)`

### status
Constraints: `enum(active|suspended), default(active)`

## Outputs

| Field | Type | Description                |
|-------|------|----------------------------|
| `id`  | uuid | The newly created user id. |

## Entities

### [[auth.user|auth::user]]
**As input:** shape · **Effect:** create

| Field        | Touch   | Type      | Mapping         | Notes |
|--------------|---------|-----------|-----------------|-------|
| `id`         | written | uuid      | `uuid()`        |       |
| `org_id`     | written | uuid      | `input.org_id`  |       |
| `email`      | written | email     | `input.email`   |       |
| `created_at` | written | timestamp | `now()`         |       |

## Behavior
1. `B1` — Validate the email against the rules in [[auth-user-management]].
2. `B2` — Resolve the organisation named by the input.
3. `B3` — Persist a new account row.

## Postconditions
- `Q1` — created(auth.user) — Exactly one row exists for the submitted email.
- `Q2` — unchanged(auth.org) — The organisation row is read and never written.
- `Q3` — returns(id) — The caller receives the new row's identifier.

## Errors
- `email_exists` — unique(email) — operator-facing message: "An account already exists with that email."
- `org_conflict` — unique(org_id) — operator-facing message: "That organisation slot is taken."
