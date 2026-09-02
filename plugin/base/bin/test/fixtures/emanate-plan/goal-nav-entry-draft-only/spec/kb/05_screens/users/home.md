---
id: users.home
module: users
screen: home
lifecycle: draft
---

# People

**Features:** FEAT-01

## Purpose

An administrator would land here and open the roster, but this screen is still
in design: neither built nor being built, so the link it carries is no way into
the roster — while it does mean the roster is not the app's own entry either.

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
