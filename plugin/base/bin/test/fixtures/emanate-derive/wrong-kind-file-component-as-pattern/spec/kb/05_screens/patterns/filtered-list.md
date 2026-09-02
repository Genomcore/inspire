# Pattern: filtered-list

**Purpose:** a roster the user narrows before acting on it.
**State:** to-extract
**Components:** [[../components/filter]] [[../components/paginator]]

A collection view with a filter bar above the records and a paginator below
them. The two components it names are declared edges, never an assumed tier.

## Structure

1. The filter bar.
2. The records.
3. The paginator.

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `toolbar` | required | dispatch | the filters and the sort control |
| `body` | required | data | the records themselves |
| `status` | optional | static | count, selection, footer meta |

## Variants

- **Faceted** — a sidebar of facet groups in place of the toolbar.
