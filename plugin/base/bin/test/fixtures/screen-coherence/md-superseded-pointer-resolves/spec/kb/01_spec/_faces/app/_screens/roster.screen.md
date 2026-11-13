---
id: app.roster
module: users
screen: roster
lifecycle: superseded
superseded_by: "[app.list](list.screen.md)"
---

# Users, retired

**Features:** FEAT-01

## Purpose

An administrator comes here to scan the roster of workspace members. The screen
carries a pointer to the list that supersedes it, so a reader lands there
instead.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [auth::user::list](../../../_modules/auth/_domain/user/user.list.action.md) | the primary table feed |
