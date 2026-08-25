---
id: users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01

## Purpose

An administrator comes here to find one member of the workspace among many.
The roster leads, so the reader sees who exists before choosing anyone to act
on.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [[auth.user.create\|auth::user::create]] | primary action | → [[/users/:id]] | state `form-error` |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [[/users/:id]] | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `form-error` | `create` rejects | the field errors, inline |
