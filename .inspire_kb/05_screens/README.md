# 05 · Screens

Screen specifications and the **shared component catalog** — the visual and
interaction contract that later gets turned into code. A **screen** is the UI
spec for one navigable view; here it's named "screen" because that reads clearer.

- **Skill:** `inspire-screens` (create & validate screens using a pattern-driven
  approach).
- **Layout:**
  ```
  05_screens/
    patterns/            # reusable screen structures (starters: list, detail)
    components/          # the shared component catalog (reused when coding)
    {module}/            # screens per module
    design-system.md     # the live design system — seeded at install
  ```
- **`design-system.md`** is the project's live design system (tokens, typography,
  color, density, layout). It's **seeded at install** by copying the default
  template [`00_bootstrap/theme.md`](../00_bootstrap/theme.md), then owned here —
  edit it with `/inspire_screens design-system`. (So it isn't shipped in the bare
  template; it appears after `.inspire/install.sh` runs.)
- Screens **instantiate shared patterns** ([`patterns/`](patterns)) and use
  components from [`components/`](components); the same components are the reference
  when the UI is implemented in a prototype ([`03_prototypes`](../03_prototypes))
  or in production.

Screens realise features ([`02_features`](../02_features)) and must stay aligned
with the specs in [`04_domain`](../04_domain).
