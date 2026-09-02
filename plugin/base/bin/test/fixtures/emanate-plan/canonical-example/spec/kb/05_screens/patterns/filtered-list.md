# Pattern: filtered-list

**Purpose:** a roster the user narrows before acting on it.
**State:** to-extract
**Components:** [[../components/filter]] [[../components/list]] [[../components/paginator]]

The layout the roster screen names. Its three declared components are what put
it a wave behind them — A17's rule that a pattern and a component order only by
a declared edge, never by an assumed tier.

## Structure

1. The filter bar.
2. The records.
3. The paginator.

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `toolbar` | optional | dispatch | the filters and the sort control |
| `body` | required | data | the records themselves |
| `status` | optional | static | count, selection, footer meta |
