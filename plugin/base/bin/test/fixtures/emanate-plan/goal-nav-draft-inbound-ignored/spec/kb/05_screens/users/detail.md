---
id: users.detail
module: users
screen: detail
lifecycle: accepted
---

# User

**Features:** FEAT-01

## Purpose

An administrator comes here to read one account in full, having arrived from the
roster that is the only way in.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `record` | [[auth.user.get\|auth::user::get]] | the account itself, already stable |

### States

| Key | When | Presentation |
|---|---|---|
| `missing` | `record` returns nothing | the not-found message |
