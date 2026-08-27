---
id: users.list           # minted once, never re-derived from location
module: users
screen: list
lifecycle: accepted      # draft | accepted | stable | superseded
---

# Users

**Features:** FEAT-01
**Pattern:** [[../patterns/list]]

## Purpose

An administrator comes here to find one member of the workspace among many.
The roster leads, so the reader sees who exists before choosing anyone to act
on.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [[auth.user.create\|auth::user::create]] | primary action | → [[users.detail]] | state `form-error` |
| `delete` | [[auth.user.delete\|auth::user::delete]] | row action | refresh `main` | state `form-error` |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [[users.detail]] | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
| `form-error` | `create` rejects | the field errors, inline |
