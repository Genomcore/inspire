---
id: auth::profile::view
module: auth
entity: profile
action: view
lifecycle: draft
requires:
  - "[[auth.profile.edit|auth::profile::edit]]"
---

# View profile — `/profile`

**Features:** FEAT-01
**Pattern:** [[../patterns/detail]]

## Purpose
XXX: describe what this screen shows.

## Entities

### [[auth.profile|auth::profile]]
**Effect:** read

| Field   | Touch | Type    | Mapping | Notes |
|---------|-------|---------|---------|-------|
| `theme` | read  | integer |         |       |

## Instantiation

- **Data:** the profile entity.
