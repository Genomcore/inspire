---
id: users.home
module: users
screen: home
lifecycle: accepted
---

# People

**Features:** FEAT-01

## Purpose

An administrator lands here from the main menu and picks the roster they want to
work in. Nothing in the suite navigates here, which makes it a nav root.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `summary` | [[auth.user.list\|auth::user::list]] | the headline counts |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `browse` | [[users.list]] | opening the roster |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `summary` returns zero rows | the no-accounts-yet message |
