# Pattern: list

**Purpose:** a roster with a primary action.
**State:** to-extract

Two rows key the same region, and one row keys nothing at all. Either way a
claim stops naming one hole, so the fingerprint stops telling two apart.

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `body` | required | data | the records themselves |
| `body` | optional | static | contextual guidance |
|  | optional | static | count, selection, footer meta |
