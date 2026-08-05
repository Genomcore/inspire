# `inspire_kb` — the INSPIRE knowledge base

The project's **navigable knowledge graph**. This is where intent lives: what
the product is, why it's shaped the way it is, and what "correct" means — the
source of truth the agents read from and write to.

Each numbered folder is a layer of the graph, operated by a matching skill in
[`.claude/skills/`](../.claude/skills):

| Folder | Holds | Skill |
|--------|-------|-------|
| [`00_bootstrap`](00_bootstrap) | The foundation: tech `stack.md` + design-system `theme.md` (base context for all skills), plus the optional surface roster `surfaces.md` (owned by `inspire-surface`) | `inspire-bootstrap` |
| [`01_adr`](01_adr) | Architecture Decision Records | `inspire-adr` |
| [`02_modules`](02_modules) | Module **hubs + registry** — the per-module second-level index linking its features, screens, specs and module ADRs | `inspire-module` |
| [`03_features`](03_features) | Product intent — one file per use case, per module (indexed from `02_modules`) | `inspire-feature` |
| [`04_domain`](04_domain) | The logical domain — data model (entities) + behavior (actions), coupled | `inspire-domain` |
| [`05_screens`](05_screens) | screen specs + the shared component catalog | `inspire-screens` |
| [`06_spikes`](06_spikes) | External vertical-spike **knowledge**: repo links + imported learnings + gap analysis (the horizontal prototype keeps no file here — its insights land in the other layers) | `inspire-spike` |
| [`98_lessons`](98_lessons) | **Meta:** durable, version-stamped one-line **lessons** that teach the `inspire-*` skills how to behave here — relevant locally, distilled upstream by the observer | `inspire-lesson` |
| [`99_tracker`](99_tracker) | Tickets and work log | `inspire-task` |

Every project is a **suite**, and most are suites of one; a project that declares
two or more surfaces splits `05_screens` and downstream code by surface while
keeping one shared `04_domain` — see
[`.claude/skills/_references/surface-scope.md`](../.claude/skills/_references/surface-scope.md)
for the full rules.

Coherence across these layers is protected mechanically by the validators in
[`.inspire/bin/`](../.inspire/bin) and the git-time hooks in
[`.inspire/hooks/`](../.inspire/hooks).

> This is a **template skeleton**. On a new project the folders start empty
> (each keeps a `README.md` and, where needed, a `.gitkeep`); the skills fill
> them in as the system grows.
