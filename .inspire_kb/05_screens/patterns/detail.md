# Pattern: detail

A **single-record view** — everything about one entity instance, on its own route
(`/{module}/{resource}/:id`). Reached by clicking a row in a [`list`](list.md).

## Structure

1. **Header** — resource icon + title + key meta (left); actions + back link (right).
2. **Tabs / sections** — the record's facets (Overview first, Settings last is the
   usual ordering).
3. **Body** — the fields and related collections for the active tab.

Tokens come from the design system ([`../design-system.md`](../design-system.md)).

## Slots

| Slot | What the screen provides |
|------|--------------------------|
| `title` / `meta` | the record's name and identifying fields |
| `data` | the source record (a `04_domain` entity, resolved by id) |
| `actions` | edit / delete / domain actions on this record |
| `tabs` | the facets (Overview, related lists, Settings, …) |
| `back` | the list route to return to |

## Variants

- **Single-page** — no tabs (small records).
- **Editor** — the detail in an editable mode (or a dedicated `/edit` route).

## Notes

Each detail screen is a route, not a drawer/overlay — that keeps deep links and
back-navigation working. A screen may opt into an overlay only when it says so
explicitly.
