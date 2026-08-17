---
id: auth::user
lifecycle: accepted
---

# auth::user

## Purpose

The tenant owns a set of users.

## Rationale

Because the model follows the decision recorded in [[adr-auth-sessions]], the tenant stays the billing owner of every account, and a user never pays for anything on its own.

## Fields

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | The primary key. |

## Touched by

| Action | Touch | Notes |
|---|---|---|
| [[auth.user.create|auth::user::create]] | write | It inserts the row. |
