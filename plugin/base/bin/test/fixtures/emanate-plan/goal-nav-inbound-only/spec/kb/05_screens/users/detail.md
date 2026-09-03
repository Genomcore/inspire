---
id: users.detail
module: users
screen: detail
lifecycle: accepted
---

# User

**Features:** FEAT-01

## Purpose

An administrator comes here to read one account in full, and goes on to its
history when the record alone does not answer the question.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `record` | [[auth.user.get\|auth::user::get]] | the account itself |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `history` | [[users.audit]] | asking what changed |

### States

| Key | When | Presentation |
|---|---|---|
| `missing` | `record` returns nothing | the not-found message |
