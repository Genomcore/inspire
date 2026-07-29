# 02 · Modules

The **module registry and hubs** — the second-level index of the product (after the
global `00_bootstrap`). A *module* is the organizing unit that groups a slice of the
product; this layer holds its **hub**, decoupled from the layers it links.

- **Skill:** `inspire-module` (create / review / update / scan / delete).
- **Layout:**
  ```
  02_modules/
    {module}.md   # one hub per module: overview + relationships + links to its
                  # features (03_features/), screens (05_screens/), specs
                  # (04_domain/), spikes (06_spikes/) and module-scoped ADRs
    _index.md     # the module registry (list of all modules)
    _template.md  # copy this for a new module hub
    README.md     # this file
  ```

Each module's detailed content lives in the per-layer subfolders
(`03_features/{module}/`, `05_screens/{module}/`, `04_domain/{module}/`), **kept in
sync** with the hub. The hub is the one place that sees the whole module — so the
feature and screen folders are indexed from here, rather than a module being "a
folder of features."
