# Layout: collection

**Purpose:** the frame a collection sits in.
**State:** to-extract
**Pattern:** [[../patterns/detail]]

## Geometry

| Element | Property | Value | Source |
|---|---|---|---|
| Content region | padding | `{spacing.6}` | design-tokens.json |
| Toolbar | height | 44px | reference |
| Table | row height | `{size.table-row}` | design-system.md § Density |

## Breakpoints

| Range | Region | Change | Source |
|---|---|---|---|
| every supported width | Page | never scrolls sideways | reference |
| tablet | Toolbar | the filters wrap under the search | as shell |
