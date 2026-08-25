---
id: users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the page of users — resolves through the action-id index |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `archive` | [[auth.user.archive\|auth::user::archive]] | the row menu | refresh `main` | - |
