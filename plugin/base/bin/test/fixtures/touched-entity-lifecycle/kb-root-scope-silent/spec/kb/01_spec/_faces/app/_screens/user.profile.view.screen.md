---
id: app.user.profile.view
module: auth
entity: profile
action: view
lifecycle: draft
requires:
  - "[auth::profile::edit](../../../_modules/auth/_domain/profile/profile.edit.action.md)"
screen: user.profile.view
---

# View profile — `/profile`

**Features:** FEAT-01
**Pattern:** [detail](../../../_design-system/patterns/detail.pattern.md)

## Purpose
XXX: describe what this screen shows.

## Entities

### [auth::profile](user.profile.screen.md)
**Effect:** read

| Field   | Touch | Type    | Mapping | Notes |
|---------|-------|---------|---------|-------|
| `theme` | read  | integer |         |       |

## Instantiation

- **Data:** the profile entity.
