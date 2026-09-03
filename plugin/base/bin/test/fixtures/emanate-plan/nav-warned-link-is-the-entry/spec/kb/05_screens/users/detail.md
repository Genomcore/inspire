---
id: users.detail
module: users
screen: detail
lifecycle: accepted
---

# User

**Features:** FEAT-01

## Purpose

An administrator comes here to read one account in full, and goes back to the
roster when they are done — which is the other half of the cycle only
`users.home` links into.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `record` | [[auth.user.get\|auth::user::get]] | the account itself |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `roster` | [[users.list]] | leaving the account |

### States

| Key | When | Presentation |
|---|---|---|
| `missing` | `record` returns nothing | the not-found message |
