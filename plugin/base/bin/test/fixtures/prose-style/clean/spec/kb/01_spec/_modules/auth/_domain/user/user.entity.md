---
id: auth::user
lifecycle: accepted
---

# auth::user

## Purpose

The tenant owns a set of users, and each user signs in with an email.

## Rationale

The model follows the decision in [adr-auth-sessions](../../../../_adr/auth-sessions.adr.md), which keeps the tenant as the billing owner.

## Invariants

- Each email belongs to exactly one user.

## Fields

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | The primary key. |

## Touched by

| Action | Touch | Notes |
|---|---|---|
| [auth::user::create](user.create.action.md) | write | It inserts the row. |
