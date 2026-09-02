# Pattern: list

**Purpose:** a roster with a primary action.
**State:** to-extract

A layout whose region rows leave both closed vocabularies. `records` is not a
binding kind and `mandatory` is not a fill, so a region that should have
demanded a data binding demands nothing.

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `body` | mandatory | records | the records themselves |
| `status` | optional | static | count, selection, footer meta |
