# Component: data-table

**Purpose:** a sortable table of records.
**State:** to-extract

The shared roster table, recognised in several screens and not yet promoted.

## Structure

1. A header row, one cell per column.
2. The record rows.
3. A footer carrying the count.

## API / Slots

| Prop / slot | What it carries |
|------|--------------------------|
| `rows` | the records to render |
| `columns` | which fields become columns, in order |
| `on-row-click` | the handler a row activation calls |

## States

| Key | When | Presentation |
|---|---|---|
| `empty` | `rows` is empty | the empty-collection message, no header |
| `loading` | `rows` has not resolved yet | skeleton rows at the last known count |

## Variants

- **Compact** — when the roster is dense.
- **Selectable** — when the caller needs a selection column.

## Instances

- the account roster
- the audit log
