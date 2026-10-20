---
id: users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01
**Pattern:** [[../patterns/list]]
**Components:** [[../components/person-chip]]

## Purpose

An administrator comes here to find one member of the workspace among many.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |

## Render

### Table

| Value | Field type | Component | Treatment | Align | Narrow |
|---|---|---|---|---|---|
| Name | text | `person-chip` | the full name | left | sticky |
| Email | text | — | `{font.size.sm}` | left | hidden below laptop |
| Last seen | date | — | relative | right | scroll |

### Header

| Value | Field type | Component | Treatment | Align |
|---|---|---|---|---|
| Member count | number | — | `{font.size.xs}` | left |
