# Pattern: form

**Purpose:** a set of fields the user fills in and submits.
**State:** to-extract

A labelled field stack over a submit row. The wrapped items below are the shape
this fixture exists for: an author keeping the vault at 80 columns.

## Structure

1. The field stack.
2. The submit row.

## Regions

| Region | Fill | Accepts | What it holds |
|---|---|---|---|
| `fields` | required | data | the labelled inputs |
| `actions` | required | dispatch | submit and cancel |

## Variants

- **Coded** — fields bound to the study's configured value sets
  ([[adr-coded-terminology]]), each showing the code system alongside the
  display text.
- **Inline** — the stack rendered inside a row it edits in place.

## Notes

- A field bound to a value set states which system the value came from.
