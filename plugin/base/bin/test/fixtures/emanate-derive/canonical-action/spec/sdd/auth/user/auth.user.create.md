---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: draft           # draft | accepted | stable | superseded
requires:
  - "[[auth.password.hash|auth::password::hash]]"
superseded_by: null        # required iff lifecycle == superseded
---

## Purpose
Create a new platform user account from an email + password pair. The [[auth-user-management|user-management subsystem]] is the source of truth for identity; this verb is its admin-side account-provisioning entry point. Identity model, scopes, and the auth-provider integration are defined in [[adr-auth-01-identity-model]].

## Inputs

| Parameter  | Type     | Required | Description                              |
|------------|----------|----------|------------------------------------------|
| `email`    | email    | yes      | Account login email.                     |
| `password` | password | yes      | Plaintext password; hashed before write. |

### password
Constraints: `len(12, 128)`

The floor is the platform-wide minimum set by [[adr-auth-02-password-hashing]]; the ceiling exists so a pathological input cannot turn hashing into a denial of service.

## Outputs

| Field | Type | Description                |
|-------|------|----------------------------|
| `id`  | uuid | The newly created user id. |

## Entities

### [[auth.user|auth::user]]
**As input:** shape · **Effect:** create

| Field          | Touch   | Type      | Mapping       | Notes |
|----------------|---------|-----------|---------------|-------|
| `id`           | written | uuid      | `uuid()`      |       |
| `email`        | written | email     | `input.email` |       |
| `created_at`   | written | timestamp | `now()`       |       |

## Preconditions
- `P1` — actor(admin) — Only an administrator provisions accounts directly; the public path is [[auth.user.signup|auth::user::signup]].
- `P2` — absent(auth.user) — No account may already hold the submitted email, per the identity model in [[adr-auth-01-identity-model]].

## Behavior
1. `B1` — Validate the email format against the rules described in [[auth-user-management#email-constraints|the user-management email rules]].
2. `B2` — Hash the password using [[auth.password.hash|auth::password::hash]], following the auth-provider integration model in [[adr-auth-01-identity-model]].
3. `B3` — Persist a new user row with the hashed credential.

## Postconditions
- `Q1` — created(auth.user) — Exactly one row exists for the submitted email.
- `Q2` — returns(id) — The caller receives the new row's identifier.

## Errors
- `email_exists` — unique(email) — operator-facing message: "An account already exists with that email."
