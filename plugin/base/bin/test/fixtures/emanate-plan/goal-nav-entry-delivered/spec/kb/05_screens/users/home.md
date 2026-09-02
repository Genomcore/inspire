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
is already delivered, so it is the slice's live entry — and plan never derives
it, which is why its navigation is invisible to the reachability walk.

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
