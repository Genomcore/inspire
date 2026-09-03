# Pattern: list

**Purpose:** a roster with a primary action.

A repeatable roster layout that declares no `**State:**` at all — the pre-ED10
catalog entry, from before an entry's state was its lifecycle. It says neither
that the layout is delivered nor that it is waiting to be written, so the screen
naming it has nothing to wait for.

## Structure

1. A header with the primary action.
2. The roster itself.

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `header` | required | static | the collection's name |
| `body` | required | data | the records themselves |
