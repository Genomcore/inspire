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

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [auth::user::list](../../../_modules/auth/_domain/user/user.list.action.md) | the primary table feed |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [users.detail](../../users/_screens/detail.screen.md) | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
