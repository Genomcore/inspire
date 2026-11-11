---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## ENT1: Purpose
The user account entity, grounded in [[adr-auth-sessions]].

## ENT2: Rationale
The identity model follows [[adr-auth-sessions]].

## ENT3: Invariants
- `I1` — unique(org_id, email) — An email is unique per organisation.
- `I2` — unique(nickname) — A nickname is unique.

## ENT4: Fields

| Field    | Type  | Notes                          |
|----------|-------|--------------------------------|
| `id`     | uuid  | The primary key.               |
| `org_id` | uuid  | The owning organisation.       |
| `email`  | email | The canonical identity handle. |

### id
Constraints: `nonnull, unique, immutable`

### org_id
Constraints: `nonnull, immutable`

### email
Constraints: `nonnull, pattern(/.+@.+/)`

### ghost
Constraints: `nonnull`

## ENT5: Touched by

| Action | Touch | Notes |
|---|---|---|
| [[auth.user.create|auth::user::create]] | write | It inserts the row. |
| [[auth.user.get|auth::user::get]] | read | It reads one row. |
