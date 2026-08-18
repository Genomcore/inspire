---
id: auth::profile::edit
module: auth
entity: profile
action: edit
lifecycle: stable
requires:
  - "[[auth.profile.view|auth::profile::view]]"
  - "[[auth.profile.missing|auth::profile::missing]]"
superseded_by: "[[nowhere.at.all|nowhere::at::all]]"
---

# Edit profile — `/profile/edit`

**Features:** FEAT-01
**Pattern:** [[../patterns/form]]

## Purpose
FIXME: describe what this screen edits.

## Entities

### [[auth.profile|auth::profile]]
**Effect:** update

| Field   | Touch   | Type   | Mapping | Notes |
|---------|---------|--------|---------|-------|
| `theme` | written | string |         |       |

## Instantiation

- **Data:** the profile entity.
