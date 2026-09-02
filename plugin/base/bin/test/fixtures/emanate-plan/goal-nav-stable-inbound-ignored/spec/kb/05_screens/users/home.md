---
id: users.home
module: users
screen: home
lifecycle: stable
---

# People

**Features:** FEAT-01

## Purpose

An administrator lands here from the main menu and opens the roster. This screen
is `stable`, so it is out of the frontier and its navigation is never consulted:
a delivered screen that must gain a link for a new page to be reachable is
itself work, so the vault below is incoherent and `PR-23` says so.

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
