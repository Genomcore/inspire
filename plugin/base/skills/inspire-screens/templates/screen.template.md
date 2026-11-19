---
id: {face}.{slug}
module: {module}
screen: {screen}
lifecycle: draft
---

<!-- Required: the frontmatter identity block (id · module · screen · lifecycle),
     the H1 title, the Features line, a non-empty ## Purpose, and ## Bindings
     with at least one of its five subsections (### Parameters · ### Data ·
     ### Dispatches · ### Navigation · ### States).
     Optional / presence-free: the Pattern, Layout and Components lines,
     ## Render, ## Module-specific deviations, ## Current prototype, ## Notes.
     A screen naming a Pattern names the Layout that frames it, and a screen
     declaring ### Data carries ## Render; screen-presentation.sh warns when
     either is missing.
     This split is the single source of the two lists the validator encodes.

     `id` is minted once as {face}.{slug} — the face this file sits in and the
     file's slug ({slug}.screen.md) — and never re-derived from location. Renaming
     or moving the file never touches it. The route is NOT authored here — it
     derives from `module` + `screen` under the face's shell; see
     references/format-screen.md.

     Links are relative Markdown links, per
     .claude/skills/_references/kb-links.md. A linked screen, pattern,
     layout or component that does not exist yet is created from its template in
     the same turn: a screen at lifecycle: draft, a catalog entry at
     **State:** to-extract. -->
# {Screen Title}

**Features:** FEAT-01, FEAT-02
**Pattern:** [{pattern-name}](../../../_design-system/patterns/{pattern-name}.pattern.md)
**Layout:** [{layout-name}](../../../_design-system/layouts/{layout-name}.layout.md)
**Components:** [{component-name}](../../../_design-system/components/{component-name}.component.md)

<!-- One paragraph of prose — no table, no list: who comes to this screen, for
     which task, and what they see first. It orients a human reader and gives
     the emanating agent the screen's intent, which the feature links alone do
     not carry. It never restates the bindings below (those rows are the
     contract) and never names a route (routes derive from `module` +
     `screen`). Present state, the product's own words, kept short. -->
## SCR1: Purpose

{who comes here} {for which task}. {what they see first, and what they do from there.}

## SCR2: Bindings

<!-- The screen's own semantics, declared whether or not a Pattern is named.
     Keys are screen-local and unique per subsection; each row generates one
     claim ({id}/param/{key} · {id}/data/{key} · {id}/dispatch/{key} ·
     {id}/nav/{key} · {id}/state/{key}). Drop a subsection this screen has
     nothing to declare in.
     A pipe-syntax link inside a table cell escapes its pipe (`\|`) — an
     unescaped one would end the cell. A bare colon-form link is equally valid.

     One transition, one declaration, one claim: a transition a dispatch causes
     is that dispatch's `On success`/`On error` outcome and never also a
     Navigation row. ### Navigation declares only the transitions no dispatch on
     this screen causes — a row click, a menu link, a back link, a tab.

     Every action a Data or Dispatches row binds is exposed by a bundle the
     face lists in `bundles:` (face-exposure.sh).

     The face's store: a Data row reads key `k` with store `k` in its Action
     cell. A dispatch's On success may add set store `k` or refresh store `k`,
     joined to another outcome by `; `. A Navigation row's Then sets a client
     key from a parameter it passes: set store `k` from param `p`.

     A state's `When` anchors by naming a declared key in BACKTICKS
     (`main` returns zero rows) — an unbackticked mention is not read as an
     anchor and the state is reported as free-floating.

     ### Parameters declares the screen's inputs: a record id, a filter, a mode
     flag that loads nothing. In is `path` or `query`, and a path one is
     required. A data row that relies on one, and a transition that passes one
     to its target, says so with param `{key}` — the target must declare it. -->

### SCR3: Parameters

| Key | In | Type | Required | Notes |
|---|---|---|---|---|
| `id` | path | uuid | yes | {which record this screen shows} |
| `view` | query | enum<quick\|advanced> | no | {what the flag changes} |

### SCR4: Data

| Key | Action | Notes |
|---|---|---|
| `main` | [{module}::{entity}::{action}](../../../_modules/{module}/_domain/{entity}/{entity}.{action}.action.md) | {what this feed is for}, by param `id` |
| `{data-key}` | store `{store-key}` | {what the screen shows from the face's store} |

### SCR5: Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [{module}::{entity}::{action}](../../../_modules/{module}/_domain/{entity}/{entity}.{action}.action.md) | {what the user does} | → [{target-screen-id}]({target-slug}.screen.md) | state `{state-key}` |

### SCR6: Navigation

| Key | Target | Trigger | Then |
|---|---|---|---|
| `back` | [{target-screen-id}]({target-slug}.screen.md) | {what the user does} | — |
| `open` | [{target-screen-id}]({target-slug}.screen.md) param `{target-param-key}` | {what the user does} | set store `{client-key}` from param `{target-param-key}` |

### SCR7: States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | {what the user sees} |
| `{state-key}` | `create` rejects | {what the user sees} |

<!-- How every value this screen shows is drawn. One H3 per region of the
     pattern, in reading order; one row per column, field, meta value or
     control. Field type comes from design-system.md, Component names a
     {name}.component.md entry (write the entry, at to-extract, in the same turn),
     Treatment cites tokens by path in braces and names every glyph by its
     library and name (`lucide-folder`), Align is left · centre · right.
     A table of columns adds Narrow: always · sticky · scroll ·
     hidden below {width} — what the column does below the widest range.
     Mints no claim: a Render edit re-emanates nothing. -->
## SCR8: Render

### {Region}

| Value | Field type | Component | Treatment | Align |
|---|---|---|---|---|
| {value} | {field type} | `{component}` `{variant}` | {tokens, glyph, copy} | left |

### Table

| Value | Field type | Component | Treatment | Align | Narrow |
|---|---|---|---|---|---|
| {column} | {field type} | `{component}` | {tokens, glyph} | left | sticky |
| {column} | {field type} | — | {tokens} | right | hidden below {width} |

<!-- Optional — only when the screen deviates from the pattern's defaults, or
     when which component fills which region needs saying. -->
## SCR9: Module-specific deviations

- {describe only what deviates from the pattern defaults}

<!-- Optional — leave empty when aligned; omit the section entirely until a prototype target exists. -->
## SCR10: Current prototype

- **Target:** {prototype route(s) realizing this screen — the derived route, under the face's shell — or `none yet`}
- **Drift:** {informational misalignments between the prototype and this spec; leave empty when aligned}
  - {ADR alignment | data wiring | component adoption | gap | cosmetic} — {what differs}

<!-- Optional — presence-free. -->
## SCR11: Notes

- {domain-specific behavior, edge cases, user feedback that informed the design}
