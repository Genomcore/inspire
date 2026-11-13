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

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [auth::user::create](../../../_modules/auth/_domain/user/user.create.action.md) | primary action | → [users.detail](../../users/_screens/detail.screen.md) | - |
