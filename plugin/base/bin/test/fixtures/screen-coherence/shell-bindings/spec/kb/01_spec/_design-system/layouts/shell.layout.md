---
faces: [portal]
---

# Layout: shell

**Purpose:** the portal chrome
**State:** to-extract
**Pattern:** —

## LAY2: Geometry

| Element | Property | Value | Source |
|---|---|---|---|
| `sidebar` | width | 240px | generated |

## LAY8: Bindings

### Parameters

| Key | In | Type | Required | Notes |
|---|---|---|---|---|
| `tab` | query | text | no | |

### LAY9: Data

| Key | Action | Notes |
|---|---|---|
| `user` | store `me` | the name in the sidebar footer |
| `study` | store `study` | the study title in the sidebar |

### LAY10: Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `logout` | [auth::user::me](../../_modules/auth/_domain/user/user.me.action.md) | the sign-out button | flash a toast | — |

