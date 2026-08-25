# Pattern: list

**Purpose:** show many records of one kind and let the user find, filter and act on them.

A **collection view** — the canonical way to show many records of one kind and let
the user find, filter and act on them. Most module landing screens name this
pattern.

## Structure

1. **Header** — title + optional subtitle (left); search + primary actions (right).
2. **Tabs** (optional) — sibling views of the same collection; each with a count.
3. **Toolbar** — filters, sort, and per-view actions under the tabs.
4. **Body** — the records, as a table or a simple row list.
5. **Status bar** (optional) — count / selection / footer meta.

Tokens (spacing, type, colors, density, table-row height) come from the design
system ([`../design-system.md`](../design-system.md)) — do not restate them here.

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `header` | required | static | the collection's name and its one-line description |
| `header-actions` | optional | dispatch | the actions that add to the collection |
| `search` | optional | dispatch | the free-text query control |
| `tabs` | optional | nav | sibling views of the same collection |
| `toolbar` | optional | dispatch | filters, sort, and per-view actions |
| `body` | required | data | the records themselves, as instantiated components |
| `status` | optional | static | count, selection, footer meta |

A region is a hole: it says what kind of content it takes, never which fields that
content shows. Which columns a table renders belongs to the component filling
`body` — the screen wires its data binding into it.

## Variants

- **Plain list** — no tabs/toolbar (short, static collections).
- **Faceted** — a sidebar of facet groups instead of a toolbar (browse-heavy sets).

## Notes

Detail screens are their own route (see [`detail`](detail.md)); clicking a row
navigates there rather than opening an overlay, unless a screen explicitly opts in.
