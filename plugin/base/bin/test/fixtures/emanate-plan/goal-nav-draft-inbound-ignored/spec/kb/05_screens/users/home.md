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
in design. A draft is not emanated, so plan never reads it: the link it carries
is neither a way into the roster nor a reason to stop calling the roster the
app's own entry.

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
