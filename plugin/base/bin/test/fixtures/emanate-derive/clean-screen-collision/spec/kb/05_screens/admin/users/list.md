---
id: admin.users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01, FEAT-02
**Pattern:** [[../patterns/list]]
**Components:** [[../components/data-table]]

## Purpose

An administrator comes here to find one account among many. The roster leads, so
the reader sees who exists before choosing anyone to act on.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.get\|auth::user::get]] | the primary table feed |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [[auth.user.create\|auth::user::create]] | primary action | → [[users.detail]] | state `form-error` |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [[users.detail]] | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
| `form-error` | `create` rejects | the field errors, inline |
