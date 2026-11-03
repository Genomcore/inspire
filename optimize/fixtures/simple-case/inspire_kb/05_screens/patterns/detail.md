# Pattern: detail

**Purpose:** show everything about one entity instance, on its own route.
**State:** to-extract

A **single-record view** — everything about one entity instance, on its own route.
Reached by clicking a row in a [`list`](list.md).

## Structure

1. **Header** — resource icon + title + key meta (left); actions + back link (right).
2. **Tabs / sections** — the record's facets (Overview first, Settings last is the
   usual ordering).
3. **Body** — the fields and related collections for the active tab.

Tokens come from the design system ([`../design-system.md`](../design-system.md)).

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `header` | required | static | the record's name and its identifying meta |
| `header-actions` | optional | dispatch | the actions available on this record |
| `tabs` | optional | nav | the record's facets |
| `body` | required | data | the record itself, as instantiated components |
| `back` | optional | nav | the way back to the collection |

A region is a hole: it says what kind of content it takes, never which fields that
content shows. Which fields the body renders belongs to the components filling it —
the screen wires its data binding into them.

## Variants

- **Single-page** — no tabs (small records).
- **Editor** — the detail in an editable mode (or a dedicated edit screen of its own).

## Notes

Each detail screen is a route, not a drawer/overlay — that keeps deep links and
back-navigation working. A screen may opt into an overlay only when it says so
explicitly.
