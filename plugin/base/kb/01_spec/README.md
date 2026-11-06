# `01_spec` · the specification

Everything the product **is**: its decisions, its modules and their use cases and
domain, how it is exposed (bundles), the faces people use and their screens, the
processes that run with nobody behind them, and the design system. One directory
per concept, so reviewing a module or a face is one directory.

**No tool reads this layout.** Every validator, every skill and the INSPIRE Factory
find an artifact by its **typed extension** and resolve a link by its **id**. The
directories are for people.

```
01_spec/
├── _adr/                 ← global ADRs
├── _design-system/       ← design-system.md, its tokens, components/, layouts/, patterns/
├── _modules/{module}/    ← {module}.module.md, _adr/, _features/, _domain/{entity}/, _processes/
├── _bundles/             ← {bundle}.bundle.md
├── _faces/{face}/        ← {face}.face.md, {face}.tokens.json, _adr/, _screens/, _processes/
└── _processes/           ← global processes
```

A leading `_` on a directory means INSPIRE structure, so it never collides with a
name you chose: a project can have a module called `processes`. A module, face,
bundle, entity, action, process or screen id never starts with `_`.

## The four concepts

| Concept | What it is | Lives in |
|---|---|---|
| **Module** | A slice of the domain: its use cases, entities and actions | `_modules/{module}/` |
| **Bundle** | The unit of exposure: which actions are published together, by which package | `_bundles/` |
| **Face** | What a person uses: a set of screens with its own shell, package and tokens | `_faces/{face}/` |
| **Process** | Work that runs on a trigger (a schedule, an event, start-up), with nobody behind it | `_processes/`, or a module's or face's `_processes/` |

## Typed extensions

| Type | File | Id |
|---|---|---|
| Module hub | `{module}.module.md` | `{module}` |
| Feature (use case) | `{use-case}.feature.md` | `{use-case}` |
| Entity | `{entity}.entity.md` | `id:` (`{module}.{entity}`) |
| Action | `{entity}.{action}.action.md` | `id:` (`{module}::{entity}::{action}`) |
| ADR (decision) | `{slug}.adr.md` | `adr-{slug}` |
| ADR (rationale) | `{slug}.adr.rationale.md` | `adr-{slug}.rationale` |
| Bundle | `{bundle}.bundle.md` | `{bundle}` |
| Face | `{face}.face.md` | `{face}` |
| Screen | `{slug}.screen.md` | `id:` (`{face}.{slug}`) |
| Process | `{process}.process.md` | `id:` (`{scope}.{process}`) |
| Component · layout · pattern | `{name}.component.md` · `.layout.md` · `.pattern.md` | `{name}` |
| Design system | `design-system.md` | — |
| Tokens | `{scope}.tokens.json` | — |
| Template | `{type}.template.md` | — (never a unit) |

The typed extension is never part of an id: `list.pattern.md` is the pattern
`list`. Where the frontmatter has `id:`, it wins.

**A link to something that does not exist yet requires its file,** created from its
template with `lifecycle: draft`. A missing target then always means a broken link,
never a concept nobody wrote down.

## `_migration/`

A project that came from the layered layout (`01_adr` … `05_screens`) has a
`_migration/` directory written once by `/inspire:migrate`: the screen id map the
INSPIRE Factory reads (`id-map.json`), the plan it applied, and any file it could
not place. Nothing else writes there.
