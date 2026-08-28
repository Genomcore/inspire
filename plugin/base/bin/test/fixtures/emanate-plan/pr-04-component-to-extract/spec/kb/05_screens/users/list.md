---
id: users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01
**Components:** [[../components/data-table]]

## Purpose

An administrator comes here to find one account among many, on a roster the
shared table renders.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the roster feed |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
