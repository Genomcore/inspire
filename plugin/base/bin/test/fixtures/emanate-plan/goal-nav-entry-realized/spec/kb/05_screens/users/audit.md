---
id: users.audit
module: users
screen: audit
lifecycle: accepted
---

# Account history

**Features:** FEAT-01

## Purpose

An administrator comes here from one account to read what was done to it, and
returns to the roster the three screens circle through.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `trail` | [[auth.user.get\|auth::user::get]] | the account the trail belongs to |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `roster` | [[users.list]] | leaving the history |

### States

| Key | When | Presentation |
|---|---|---|
| `missing` | `trail` returns nothing | the not-found message |
