# 05 · Screens

Screen specifications and the **shared component catalog** — the visual and
interaction contract that later gets turned into code. A **screen** is the UI
spec for one navigable view; here it's named "screen" because that reads clearer.

- **Skill:** `inspire-screens` (create & validate screens using a pattern-driven
  approach).
- **Layout** — the shape is deterministic from the surface roster (specifically
  the count of `kind: ui` entries in
  [`00_bootstrap/surfaces.md`](../00_bootstrap/surfaces.md)), never from history:

  Roster absent, or a single UI surface (today's default, and every suite-of-one):
  ```
  05_screens/
    patterns/            # reusable screen structures (starters: list, detail)
    components/          # the shared component catalog (reused when coding)
    {module}/            # screens per module
    design-system.md     # the live design system — seeded at install
  ```

  Two or more UI surfaces declared — surface-first:
  ```
  05_screens/
    patterns/            # reusable screen structures — suite-wide, top level
    components/          # the shared component catalog — suite-wide, top level
    design-system.md     # the live design system — suite-wide, top level
    shared/{module}/     # screens used by more than one UI surface
    {surface}/{module}/  # screens per module, one tree per UI surface
  ```

  `patterns/`, `components/` and `design-system.md` never move — they sit beside
  the surface trees at top level in both shapes; they are never duplicated inside
  a surface directory. Full rules on surfaces, `shared/` and scope resolution are
  in
  [`.claude/skills/_references/surface-scope.md`](../../.claude/skills/_references/surface-scope.md).
- **`design-system.md`** is the project's live design system (tokens, typography,
  color, density, layout). It's **seeded by `materialize.sh`** by copying the default
  template [`00_bootstrap/theme.md`](../00_bootstrap/theme.md), then owned by
  `/inspire-bootstrap design-system` (screens **read** its tokens, they don't edit
  them). (So it isn't shipped in the bare template; it appears after
  `/inspire:init` runs.)
- Screens **instantiate shared patterns** ([`patterns/`](patterns)) and use
  components from [`components/`](components); the same components are the reference
  when the UI is implemented in the prototype ([`/prototype`](../../prototype))
  or in production.

Screens realise features ([`03_features`](../03_features)) and must stay aligned
with the specs in [`04_domain`](../04_domain).
