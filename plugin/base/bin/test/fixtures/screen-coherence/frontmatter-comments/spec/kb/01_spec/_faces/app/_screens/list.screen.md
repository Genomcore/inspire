---
id: app.list
module: users
screen: list
lifecycle: accepted      # draft | accepted | stable | superseded
---

# Users

**Features:** FEAT-01
**Pattern:** [list](../../../_design-system/patterns/list.pattern.md)

## Purpose

An administrator comes here to find one member of the workspace among many.
The roster leads, so the reader sees who exists before choosing anyone to act
on.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [auth::user::list](../../../_modules/auth/_domain/user/user.list.action.md) | the primary table feed |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [auth::user::create](../../../_modules/auth/_domain/user/user.create.action.md) | primary action | → [users.detail](../../users/_screens/detail.screen.md) | state `form-error` |
| `delete` | [auth::user::delete](../../../_modules/auth/_domain/user/user.delete.action.md) | row action | refresh `main` | state `form-error` |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [users.detail](../../users/_screens/detail.screen.md) | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
| `form-error` | `create` rejects | the field errors, inline |
