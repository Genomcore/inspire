---
id: app.user.profile.edit
module: auth
entity: profile
action: edit
lifecycle: stable
requires:
  - "[auth::profile::view](../../../_modules/auth/_domain/profile/profile.view.action.md)"
  - "[auth::profile::missing](../../../_modules/auth/_domain/profile/profile.missing.action.md)"
superseded_by: "[nowhere::at::all](../../../_modules/nowhere/_domain/at/at.all.action.md)"
screen: user.profile.edit
---

# Edit profile — `/profile/edit`

**Features:** FEAT-01
**Pattern:** [form](../../../_design-system/patterns/form.pattern.md)

## Purpose
FIXME: describe what this screen edits.

## Entities

### [auth::profile](user.profile.screen.md)
**Effect:** update

| Field   | Touch   | Type   | Mapping | Notes |
|---------|---------|--------|---------|-------|
| `theme` | written | string |         |       |

## Instantiation

- **Data:** the profile entity.
