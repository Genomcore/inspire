# `_design-system/` · tokens, components, layouts and patterns

The project's one design system, shared by every face.

```
_design-system/
  design-system.md              # the live design system — seeded at install
  design-system.tokens.json     # its token values, W3C Design Tokens — seeded at install
  theme.md · theme.tokens.json  # the defaults the two above are seeded from
  components/{name}.component.md
  layouts/{name}.layout.md
  patterns/{name}.pattern.md  # starters: list, detail
```

A face can add tokens of its own in `_faces/{face}/{face}.tokens.json`.

- **`design-system.md`** is the project's live design system (typography, color,
  density, layout, icons, supported viewports, and the reference the layer is
  measured from), and **`design-system.tokens.json`** holds its values in the
  [W3C Design Tokens format](https://www.designtokens.org/tr/drafts/format/): the
  markdown says what a token means, the JSON says what it is, and every other file
  cites a token by its path in braces. Both are **seeded by `materialize.sh`** from
  the defaults `theme.md` and `theme.tokens.json` beside them, then owned
  by `/inspire-bootstrap design-system` (screens **read** the tokens, they don't
  edit them). (So neither is shipped in the bare template; they appear after
  `/inspire:init` runs. An upgraded project gets its token file from
  `/inspire-bootstrap design-system backfill`.)

## Four ownerships

Design-system tokens sit above everything. Below them, patterns, layouts and
components are **siblings** — none depends on another by construction — and
screens compose them:

| Owner | Owns | Never owns |
|---|---|---|
| a **component** entry | its props, and the states it renders | where it is placed |
| a **pattern** entry | its regions (named holes) | the fields its content shows, and any measurement |
| a **layout** entry | the geometry those regions sit at, per supported width | what fills them |
| a **screen** | the wiring: data → components, components → regions, and how each value it shows is drawn (`## Render`) | tokens, geometry, props |

A region is a hole, never a mirror of some component's props. That is why a
pattern's `## Regions` table says only how a hole is filled (`required` /
`optional`) and what kind of content it accepts (`data` · `dispatch` · `nav` ·
`static`).

All three catalog entries carry a `**State:**` line — `to-extract` (authored, no code
yet) or `implemented` (built). That line is the entry's lifecycle: the emanation
loop reads it exactly as it reads a domain artifact's `lifecycle:`, so a
`to-extract` entry is a unit it emanates and the screens naming it wait for its
wave rather than refusing over it.

**Skills:** `inspire-bootstrap design-system` (the design system and its tokens),
`inspire-screens` (components, layouts, patterns).
