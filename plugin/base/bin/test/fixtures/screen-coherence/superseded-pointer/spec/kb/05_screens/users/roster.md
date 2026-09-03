---
id: users.roster
module: users
screen: roster
lifecycle: superseded
superseded_by: "[[users.nowhere]]"
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
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |
