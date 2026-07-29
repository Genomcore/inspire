# Pattern: list

A **collection view** — the canonical way to show many records of one kind and let
the user find, filter and act on them. Most module landing screens instantiate
this.

## Structure

1. **Header** — title + optional subtitle (left); search + primary actions (right).
2. **Tabs** (optional) — sibling views of the same collection; each with a count.
3. **Toolbar** — filters, sort, and per-view actions under the tabs.
4. **Body** — the records as a table (rows of cells) or a simple row list.
5. **Status bar** (optional) — count / selection / footer meta.

Tokens (spacing, type, colors, density, table-row height) come from the design
system ([`../design-system.md`](../design-system.md)) — do not restate them here.

## Slots

| Slot | What the screen provides |
|------|--------------------------|
| `title` / `subtitle` | the collection's name and one-line description |
| `data` | the data source (a `04_domain` entity or the prototype's mock table) |
| `columns` | the fields shown per record |
| `primary_action` | e.g. `[+ New]` → a create route |
| `row_action` | what clicking a row does (usually → the `detail` pattern) |
| `filters` / `sort` | the toolbar controls |
| `tabs` | sibling views, if any |

## Variants

- **Plain list** — no tabs/toolbar (short, static collections).
- **Faceted** — a sidebar of facet groups instead of a toolbar (browse-heavy sets).

## Notes

Detail screens are their own route (see [`detail`](detail.md)); clicking a row
navigates there rather than opening an overlay, unless a screen explicitly opts in.
