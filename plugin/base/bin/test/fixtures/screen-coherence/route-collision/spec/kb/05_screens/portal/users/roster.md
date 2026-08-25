---
id: portal.users.list
module: users
screen: list
lifecycle: draft
---

# Users, again

**Features:** FEAT-01

## Purpose

A portal visitor comes here to browse the same roster under the portal shell.
The list leads, and each row opens the record behind it.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |
