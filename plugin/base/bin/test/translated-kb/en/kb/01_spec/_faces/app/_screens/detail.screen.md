---
id: app.detail
module: users
screen: detail
lifecycle: accepted
---

# User

**Features:** FEAT-01

## SCR1: Purpose

An administrator comes here to read one account in full.

## SCR2: Bindings

### SCR3: Parameters

| Key | In | Type | Required | Notes |
|---|---|---|---|---|
| `id` | path | uuid | yes | the account shown |

### SCR4: Data

| Key | Action | Notes |
|---|---|---|
| `record` | [[auth.user.get\|auth::user::get]] | the account named by param `id` |

### SCR7: States

| Key | When | Presentation |
|---|---|---|
| `missing` | `record` returns nothing | the not-found message |

## SCR8: Render

### Table

| Value | Field type | Component | Treatment | Align | Narrow |
|---|---|---|---|---|---|
| `email` | email | `link` | body text | left | always |
| `org_id` | uuid | — | muted | left | wide |
