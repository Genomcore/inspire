---
id: users.audit
module: users
screen: audit
lifecycle: stable
---

# Account history

**Features:** FEAT-01

## Purpose

An administrator reads what was done to an account here. The screen is already
delivered, and it navigates nowhere — so it is no way into the roster slice, and
a vault holding it is still a vault whose roster has no entry.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `trail` | [[auth.user.get\|auth::user::get]] | the account the trail belongs to |

### States

| Key | When | Presentation |
|---|---|---|
| `missing` | `trail` returns nothing | the not-found message |
