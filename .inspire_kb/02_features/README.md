# 02 · Features

Product intent, organised by module. This is what the system does and for whom.

- **Skills:** `inspire-module` (module lifecycle — scaffold / review / update /
  remove) and `inspire-feature` (feature & use-case lifecycle).
- **Layout:**
  ```
  02_features/
    {module}/
      _index.md            # module overview + feature index
      {use-case}.md        # one file per use case
  ```
- One **subfolder per module**; inside, **one file per use case**.

Features reference decisions in [`01_adr`](../01_adr), are realised as specs in
[`04_specs`](../04_specs) and screens in [`05_ui`](../05_ui), and are explored
through [`03_prototypes`](../03_prototypes).
