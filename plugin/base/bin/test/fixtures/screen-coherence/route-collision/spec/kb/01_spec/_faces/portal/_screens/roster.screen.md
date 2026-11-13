---
id: portal.roster
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
| `main` | [auth::user::list](../../../_modules/auth/_domain/user/user.list.action.md) | the primary table feed |
