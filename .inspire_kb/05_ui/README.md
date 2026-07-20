# 05 · UI

UI specifications and the **shared component catalog** — the visual and
interaction contract that later gets turned into code.

- **Skill:** `inspire-ui` (create & validate UISpecs using a pattern-driven
  approach).
- **Layout:**
  ```
  05_ui/
    patterns/            # reusable UI patterns screens instantiate
    components/          # the shared component catalog (reused when coding)
    {module}/            # screen specs per module
    design-system.md     # tokens, typography, spacing
  ```
- Screens **instantiate shared patterns** and use components from
  [`components/`](components); the same components are the reference when the
  UI is implemented in a prototype ([`03_prototypes`](../03_prototypes)) or in
  production.

UISpecs realise features ([`02_features`](../02_features)) and must stay aligned
with the specs in [`04_specs`](../04_specs).
