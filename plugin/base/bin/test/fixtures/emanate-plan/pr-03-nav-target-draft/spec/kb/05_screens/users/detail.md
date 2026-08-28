---
id: users.detail
module: users
screen: detail
lifecycle: draft
---

# User

**Features:** FEAT-01

## Purpose

An administrator comes here to read one account in full, and goes back to the
roster when they are done.

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
