# `.inspire_kb` — the INSPIRE knowledge base

The project's **navigable knowledge graph**. This is where intent lives: what
the product is, why it's shaped the way it is, and what "correct" means — the
source of truth the agents read from and write to.

Each numbered folder is a layer of the graph, operated by a matching skill in
[`.inspire/skills/`](../.inspire/skills):

| Folder | Holds | Skill |
|--------|-------|-------|
| [`00_bootstrap`](00_bootstrap) | The foundation: tech `stack.md` + design-system `theme.md` (base context for all skills) | `inspire-bootstrap` |
| [`01_adr`](01_adr) | Architecture Decision Records | `inspire-adr` |
| [`02_modules`](02_modules) | Module **hubs + registry** — the per-module second-level index linking its features, screens, specs and module ADRs | `inspire-module` |
| [`03_features`](03_features) | Product intent — one file per use case, per module (indexed from `02_modules`) | `inspire-feature` |
| [`04_domain`](04_domain) | The logical domain — data model (entities) + behavior (actions), coupled | `inspire-domain` |
| [`05_screens`](05_screens) | screen specs + the shared component catalog | `inspire-screens` |
| [`06_spikes`](06_spikes) | External vertical-spike **knowledge**: repo links + imported learnings + gap analysis (the horizontal prototype keeps no file here — its insights land in the other layers) | `inspire-spike` |
| [`98_skill_learnings`](98_skill_learnings) | **Meta:** durable, version-stamped learnings about the `inspire-*` skills themselves — a fork's feedback bound for INSPIRE core | `inspire-learn` |
| [`99_tracker`](99_tracker) | Tickets and work log | `inspire-task` |

Coherence across these layers is protected mechanically by the validators in
[`.inspire/bin/`](../.inspire/bin) and the git-time hooks in
[`.inspire/hooks/`](../.inspire/hooks).

> This is a **template skeleton**. On a new project the folders start empty
> (each keeps a `README.md` and, where needed, a `.gitkeep`); the skills fill
> them in as the system grows.
