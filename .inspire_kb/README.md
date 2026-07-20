# `.inspire_kb` — the INSPIRE knowledge base

The project's **navigable knowledge graph**. This is where intent lives: what
the product is, why it's shaped the way it is, and what "correct" means — the
source of truth the agents read from and write to.

Each numbered folder is a layer of the graph, operated by a matching skill in
[`.inspire/skills/`](../.inspire/skills):

| Folder | Holds | Skill |
|--------|-------|-------|
| [`00_bootstrap`](00_bootstrap) | The foundation: tech `stack.md` + design-system `theme.md` (base context for all skills) | `inspire-bootstrap` |
| [`01_adr`](01_adr) | Architecture Decision Records | `inspire-workspace` |
| [`02_features`](02_features) | Product intent — one folder per module, one file per use case | `inspire-module`, `inspire-feature` |
| [`03_prototypes`](03_prototypes) | Prototype **knowledge**: horizontal learnings (code at [`/prototype`](../prototype)) + links to external vertical spike repos | `inspire-prototype` |
| [`04_domain`](04_domain) | The logical domain — data model (entities) + behavior (actions), coupled | `inspire-object` |
| [`05_screens`](05_screens) | screen specs + the shared component catalog | `inspire-screens` |
| [`06_tracker`](06_tracker) | Tickets and work log | `inspire-workspace` |

Coherence across these layers is protected mechanically by the validators in
[`.inspire/bin/`](../.inspire/bin) and the git-time hooks in
[`.inspire/hooks/`](../.inspire/hooks).

> This is a **template skeleton**. On a new project the folders start empty
> (each keeps a `README.md` and, where needed, a `.gitkeep`); the skills fill
> them in as the system grows.
