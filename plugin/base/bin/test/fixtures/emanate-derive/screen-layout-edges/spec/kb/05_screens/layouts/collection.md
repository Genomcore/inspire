# Layout: collection

**Purpose:** the frame of a roster — a toolbar over the records, the status line under them.
**State:** to-extract
**Pattern:** [[../patterns/list]]

One column the width of the content area. The toolbar and the status line hold
their height at every width; the records take what is left.

## Frame

1. The toolbar, full width
2. The records, scrolling
3. The status line,
   pinned to the bottom edge

## Geometry

| Element | Property | Value | Source |
|---|---|---|---|
| `toolbar` | height | `{size.toolbar}` | design-tokens.json |
| `toolbar` | gap | `{spacing.2}` between controls | design-tokens.json |
| records area | overflow | scrolls vertically, never horizontally | reference |
| status line | padding inline | `{spacing.4}` | generated |

## Breakpoints

| Range | Region | Change | Source |
|---|---|---|---|
| every supported width | records area | takes the height the toolbar and status line leave | reference |
| tablet | `toolbar` | wraps its controls onto a second row | undecided |

## Composition

- The status line aligns with the records' first column.

## Variants

- **Faceted** — a facet rail on the inline-start edge, `{size.rail}` wide.

## Adopters

- users.list

## Notes

- Gap at 768: the toolbar's last control clips.
