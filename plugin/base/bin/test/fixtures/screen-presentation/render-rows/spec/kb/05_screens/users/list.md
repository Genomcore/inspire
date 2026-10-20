---
id: users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01
**Pattern:** [[../patterns/list]]
**Layout:** [[../layouts/collection]]

## Purpose

An administrator comes here to find one member of the workspace among many.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |

## Render

### Table

| Value | Field type | Component | Treatment | Align |
|---|---|---|---|---|
| Name | text | `person-chip` | the full name | left |

### Columns — secondary

| Value | Field type | Component | Treatment | Align | Narrow |
|---|---|---|---|---|---|
| Role | enumeration | `role-badge` `outline` + `person-chip` | the role | left | folds away |
| Team | text | lucide icon | the team name | left | hidden < 1024px |
