---
id: app.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01
**Pattern:** [list](../../../_design-system/patterns/list.pattern.md)

## Purpose

An administrator comes here to find one member of the workspace among many.
The roster leads, so the reader sees who exists before choosing anyone to act
on.

## Bindings

### Parameters

| Key | In | Type | Required | Notes |
|---|---|---|---|---|
| `q` | query | string | no | the search text, kept across reloads |

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [auth::user::list](../../../_modules/auth/_domain/user/user.list.action.md) | the primary table feed, filtered by param `search` |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [auth::user::create](../../../_modules/auth/_domain/user/user.create.action.md) | primary action | → [users.detail](detail.screen.md) param `uid` | state `form-error` |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [users.detail](detail.screen.md) param `id` | clicking a row |
| `advanced` | [users.detail](detail.screen.md) param `id`, param `tab` | the row menu's advanced entry |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
| `filtered` | `q` is set | the search text in the field, and a clear action |
| `form-error` | `create` rejects | the field errors, inline |
