# Component: record-card

**Purpose:** one record rendered as a card.
**State:** to-extract

The card the roster falls back to on narrow viewports.

## Structure

1. A header carrying the record's title and its status badge, the badge
   taking the same palette entry the roster's status column takes.
2. The body, one labelled field per configured column.
   - The label sits above its value on a narrow viewport.
3. A footer carrying the row actions.

## API / Slots

| Prop / slot | What it carries |
|------|--------------------------|
| `record` | the record to render |
| `columns` | which fields become labelled rows, in order |

## Variants

- **Compact** — the footer collapses into the header.

## Instances

- the account roster on mobile
