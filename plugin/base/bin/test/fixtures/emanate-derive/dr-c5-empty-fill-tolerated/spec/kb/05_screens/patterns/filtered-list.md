# Pattern: filtered-list

**Purpose:** a roster the user narrows before acting on it.
**State:** to-extract
**Components:** [[../components/filter]] [[../components/paginator]]

A collection view whose `status` region leaves its `Fill` cell empty. An empty
cell is the same non-answer as a dash, and `screen-coherence` — the rule that
owns the screen-to-layout join — tolerates both, so derive does too: two readers
disagreeing about what a value IS is worse than one lenient cell.

## Structure

1. The filter bar.
2. The records.
3. The paginator.

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `toolbar` | required | dispatch | the filters and the sort control |
| `body` | required | data | the records themselves |
| `status` |  |  | count, selection, footer meta |

## Variants

- **Faceted** — a sidebar of facet groups in place of the toolbar.
