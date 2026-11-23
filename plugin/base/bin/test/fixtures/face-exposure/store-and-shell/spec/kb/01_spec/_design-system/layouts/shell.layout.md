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

### LAY9: Data

| Key | Action | Notes |
|---|---|---|
| `user` | store `me` | the name in the sidebar footer |
| `study` | store `study` | the study title in the sidebar |

### LAY10: Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `bill` | [billing::invoice::list](../../_modules/billing/_domain/invoice/invoice.list.action.md) | the billing link | — | — |

