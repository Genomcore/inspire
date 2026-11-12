---
id: app.list
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
| `main` | [auth::user::list](../../../_modules/auth/_domain/user/user.list.action.md) | the primary table feed |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [auth::user::create](../../../_modules/auth/_domain/user/user.create.action.md) | primary action | refresh `main` | state `nope` |
| `import` | [auth::user::import](../../../_modules/auth/_domain/user/user.import.action.md) | toolbar action | flash the toast | - |
| `purge` | [auth::user::purge](../../../_modules/auth/_domain/user/user.purge.action.md) | toolbar action | refresh `secondary` | → [users.detail](detail.screen.md) |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
