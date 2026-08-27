---
id: users.detail
module: users
screen: detail
lifecycle: accepted
---

# User

**Features:** FEAT-01
**Pattern:** [[../patterns/list]]

## Purpose

An administrator comes here to read one account in full, after picking it out of
the roster.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `record` | [[auth.user.get\|auth::user::get]] | the account itself |

### States

| Key | When | Presentation |
|---|---|---|
| `missing` | `record` returns nothing | the not-found message |
