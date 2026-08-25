---
id: auth.login
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
| `sign-in` | [[auth.session.create\|auth::session::create]] | primary action | → [[auth.home]] | state `denied` |

### States

| Key | When | Presentation |
|---|---|---|
| `denied` | `sign-in` rejects | the form keeps its email and clears the password |
