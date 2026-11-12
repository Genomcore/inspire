# `inspire_kb` — the INSPIRE knowledge base

The project's **navigable knowledge graph**. This is where intent lives: what
the product is, why it's shaped the way it is, and what "correct" means — the
source of truth the agents read from and write to.

Each numbered folder is a part of the graph, operated by matching skills in
[`.claude/skills/`](../.claude/skills):

| Folder | Holds | Skill |
|--------|-------|-------|
| [`00_bootstrap`](00_bootstrap) | The foundation: tech `stack.md`, `project.md` (the output language), the glossary and the project's semantic types — the base context for all skills | `inspire-bootstrap` |
| [`01_spec`](01_spec) | The **specification**, by concept: global ADRs, the design system, modules (hub, use cases, entities and actions, module ADRs), bundles, faces (screens, face ADRs) and processes. Every file carries a typed extension (`.module.md`, `.feature.md`, `.entity.md`, `.action.md`, `.adr.md`, `.bundle.md`, `.face.md`, `.screen.md`, `.process.md`…) and is found by it | `inspire-adr` · `inspire-module` · `inspire-feature` · `inspire-domain` · `inspire-face` · `inspire-screens` · `inspire-process` |
| [`06_spikes`](06_spikes) | External vertical-spike **knowledge**: repo links + imported learnings + gap analysis (the horizontal prototype keeps no file here — its insights land in the specification) | `inspire-spike` |
| [`98_lessons`](98_lessons) | **Meta:** durable, version-stamped one-line **lessons** that teach the `inspire-*` skills how to behave here — relevant locally, distilled upstream by the observer | `inspire-lesson` |
| [`99_tracker`](99_tracker) | Tickets and work log | `inspire-task` |

The layout of `01_spec/` is for people: no tool depends on it. Tools find an
artifact by its typed extension, and a link is a relative Markdown link to the file — see
[`01_spec/README.md`](01_spec/README.md). A project written before this layout
reaches it with `/inspire:migrate`.

Coherence across the specification is protected mechanically by the validators in
[`.inspire/bin/`](../.inspire/bin) and the git-time hooks in
[`.inspire/hooks/`](../.inspire/hooks).

> This is a **template skeleton**. On a new project the folders start empty
> (each keeps a `README.md` and, where needed, a `.gitkeep`); the skills fill
> them in as the system grows.
