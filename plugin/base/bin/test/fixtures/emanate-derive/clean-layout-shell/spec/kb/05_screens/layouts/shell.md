# Layout: shell

**Purpose:** the surface chrome — a sidebar beside a top bar over the routed content.
**State:** to-extract
**Pattern:** —

Every route renders inside this frame.

## Frame

1. Sidebar, on the inline-start edge
2. Top bar, over the content
3. Content, the routed screen

## Geometry

| Element | Property | Value | Source |
|---|---|---|---|
| sidebar | width | `{size.sidebar}` | design-tokens.json |
| top bar | height | `{size.topbar}` | design-tokens.json |

## Breakpoints

| Range | Region | Change | Source |
|---|---|---|---|
| mobile | sidebar | collapses behind a menu button in the top bar | reference |
