---
id: users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01
**Pattern:** [[../patterns/list]]

## SCR1: Propósito

An administrator comes here to find one member of the workspace among many.
The roster leads, so the reader sees who exists before choosing anyone to act
on.

## SCR2: Vínculos

### SCR4: Datos

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |

### SCR5: Acciones

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [[auth.user.create\|auth::user::create]] | primary action | → [[users.detail]] | state `form-error` |
| `delete` | [[auth.user.delete\|auth::user::delete]] | row action | refresh `main` | state `gone` |

### SCR6: Navegación

| Key | Target | Trigger |
|---|---|---|
| `row` | [[users.detail]] | clicking a row |

### SCR7: Estados

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
| `form-error` | `create` rejects | the field errors, inline |
