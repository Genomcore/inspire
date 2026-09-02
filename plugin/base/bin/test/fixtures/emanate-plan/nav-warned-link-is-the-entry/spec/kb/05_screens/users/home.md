---
id: users.home
module: users
screen: home
lifecycle: accepted
---

# People

**Features:** FEAT-01

## Purpose

An administrator lands here from the main menu and opens the roster. The link
out was authored while `users.list` was still `draft` — a `PR-03` warning then,
never a refusal — and this screen was emanated and delivered carrying it. It
never re-enters the frontier now that the roster exists, so its outbound
navigation is the roster's only way in.

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
