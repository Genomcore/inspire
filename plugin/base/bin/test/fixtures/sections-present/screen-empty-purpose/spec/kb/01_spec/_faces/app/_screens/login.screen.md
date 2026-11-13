---
id: app.login
module: auth
screen: login
lifecycle: draft
---

# Sign in

**Features:** FEAT-01

## Purpose

## Bindings

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `sign-in` | [auth::session::create](../../../_modules/auth/_domain/session/session.create.action.md) | primary action | → [auth.home](../../auth/_screens/home.screen.md) | state `denied` |

### States

| Key | When | Presentation |
|---|---|---|
| `denied` | `sign-in` rejects | the form keeps its email and clears the password |
