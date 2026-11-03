---
id: users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01
**Pattern:** [[../patterns/list]]

## SCR1: Purpose

An administrator comes here to find one member of the workspace among many.

## SCR2: Bindings

### SCR3: Parameters

| Key | In | Type | Required | Notes |
|---|---|---|---|---|
| `q` | query | string | no | the search text |

### SCR4: Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.get\|auth::user::get]] | the feed, filtered by param `q` |

### SCR5: Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [[auth.user.create\|auth::user::create]] | primary action | → [[users.detail]] param `id` | state `gone` |

### SCR6: Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [[users.detail]] param `id`, param `tab` | clicking a row |

### SCR7: States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
| `filtered` | `q` is set | the search text in the field |
