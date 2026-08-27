---
id: users.list           # minted once, never re-derived from location
module: users
screen: list
lifecycle: draft         # draft | accepted | stable | superseded
---

# Users

**Features:** FEAT-01, FEAT-02
**Pattern:** [[../patterns/list]]
**Components:** [[../components/data-table]]

## Purpose

An administrator comes here to find one user among many. The roster leads, so
the first thing the reader sees is who exists in the workspace at all;
everything else on the screen serves that search.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | primary table feed |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [[auth.user.create\|auth::user::create]] | primary action | → [[users.detail]] | state `form-error` |
| `delete` | [[auth.user.delete\|auth::user::delete]] | row action | refresh `main` | state `error` |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [[users.detail]] | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message and the create action |
| `form-error` | `create` rejects | the field errors, inline, with the form still filled |
| `error` | `delete` rejects | the failure message, with the row still in place |
