# 03 · Features

Product intent, organised by module — **one file per use case**. This is what the
system does and for whom.

- **Skill:** `inspire-feature` (feature & use-case lifecycle). The **module** itself
  — its hub and cross-layer links — lives one layer up in
  [`02_modules`](../02_modules), owned by `inspire-module`.
- **Layout:**
  ```
  03_features/
    {module}/              # in sync with the module's hub in 02_modules/
      {use-case}.md        # one file per use case; back-links to the hub
  ```
- One **subfolder per module** — indexed from `02_modules/{module}.md` (the module
  hub), not by a local `_index`; inside, **one file per use case**.

Features reference decisions in [`01_adr`](../01_adr), are realised as specs in
[`04_domain`](../04_domain) and screens in [`05_screens`](../05_screens), and are explored
through the horizontal prototype ([`/prototype`](../../prototype)) and vertical spikes ([`06_spikes`](../06_spikes)).
