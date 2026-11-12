---
name: inspire-module
description: "Lifecycle of a module and its hub ({module}.module.md): create / review / update / scan / delete a module directory and keep the hub's links (features, entities and actions, the screens that use them, ADRs) in sync. Use when scaffolding a new module, auditing one before a PR, authoring its specs, or removing it."
---

# /inspire-module — Module-level Operations

## Scope

A **module** is the organizing unit of the product: one directory,
`inspire_kb/01_spec/_modules/{module}/`, that holds everything the module owns.

```
_modules/{module}/
  {module}.module.md                 # the hub
  _features/{use-case}.feature.md    # one file per use case
  _domain/{entity}/
    {entity}.entity.md               # the data model
    {entity}.{action}.action.md      # the behaviour
  _adr/{slug}.adr.md                 # decisions that bind this module only
  _processes/{process}.process.md    # processes scoped to this module
```

The **hub** `{module}.module.md` is the one file that sees the whole module:
overview, relationships to other modules, and links to its features, its entities
and actions, the screens that use them, and its ADRs. A module holds no screens:
they live in the faces that show them (`_faces/{face}/_screens/`) and link the
module's actions. Tools find every file by its typed extension, never by its
directory; the hub is for people.

This skill owns the hub and its propagation to what it links: features
([`/inspire-feature`](../inspire-feature/SKILL.md)), entities and actions
([`/inspire-domain`](../inspire-domain/SKILL.md)), ADRs
([`/inspire-adr`](../inspire-adr/SKILL.md)), processes
([`/inspire-process`](../inspire-process/SKILL.md)), the screens that use the module
([`/inspire-screens`](../inspire-screens/SKILL.md)), the prototype (`/prototype` by
default — resolve `prototype_root` per
[`_references/product-roots.md`](../_references/product-roots.md)), and spikes
(`06_spikes`). The hub's links stay **in sync** with what the module holds — that
is this skill's core invariant.

## Invocation

- `/inspire-module review {module}` — full consistency review before PR
- `/inspire-module create {module}` — scaffold a new module directory and its hub
- `/inspire-module update {module}` — add/remove use cases, restructure, propagate
- `/inspire-module scan {module}` — SDD-layer entry point: surface the features that
  lack realizing specs, then chain authoring into `/inspire-domain` (read-only itself)
- `/inspire-module delete {module}` — remove the module and clean every cross-reference

## Subcommands in `references/`

Every subcommand's full procedure lives in a reference file. **Before executing
any subcommand, read every reference file its index row names** — the table
below is an index, not the flow.

| Subcommand | What it does |
|---|---|
| [`review`](references/module-review.md) | Full consistency review before any PR that modifies the hub or its features |
| [`create`](references/module-edits.md) | Scaffold a new module directory and its hub |
| [`update`](references/module-edits.md) | Add/remove use cases, restructure, propagate |
| [`scan`](references/module-scan.md) | SDD-layer entry point — surface candidates and chain into `/inspire-domain` |
| [`delete`](references/module-edits.md) | Remove the module and clean every cross-reference |

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, link paths, filenames)
> stay verbatim.

> **Writing contract.** Module hubs follow
> [`_references/writing-style.md`](../_references/writing-style.md). `## Overview` and
> `## Relationships` are normative prose (R1–R6); the `## Use cases`, `## Screens`,
> `## Domain` and `## Module ADRs` link lists are structured sections (R3, R4, R6).
> Referenced, never restated — read the rules there.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **`review` is read-only.** It reports, suggests fixes, and recommends other
   skills; it never edits files. `update` / `delete` present a plan and write only on
   the operator's approval; `create` writes from the inputs the operator provides.
2. **The hub stays in sync with the module.** The hub links every `*.feature.md`,
   `*.entity.md`, `*.action.md` and `*.adr.md` under the module's directory, and
   every `*.screen.md` (in any face) that binds one of the module's actions — and
   nothing that does not exist. A module operation that updates one but leaves the
   hub inconsistent is a bug. This is the skill's core invariant; `review` enforces
   it.
3. **A link requires its target.** Links follow [kb-links.md](../_references/kb-links.md). When a write links to something that does not
   exist yet, create the target from its template in draft and name it in the
   output: an entity or action from `inspire-domain`'s templates at
   `lifecycle: draft`, a feature from `inspire-feature`'s template at
   `**State:** 🟡 Planned`, an ADR from `inspire-adr`'s template at
   `**Status:** design`, another module's hub from
   [`templates/module.template.md`](templates/module.template.md).
4. **Pending drift is acceptable.** Drift items in `## Current prototype` sections
   are informational; don't block PRs unless they contradict a current ADR (one not
   superseded or rejected).
5. **Consult the task tracker** at the start of each invocation
   (`/inspire-task list`). Known items in
   `inspire_kb/99_tracker/tickets/` are surfaced as `(tracked: TASK-{id})`.
6. **Actionable findings.** Every issue names the skill to invoke for the fix:
   - screen spec drift → `/inspire-screens`
   - Prototype drift → `/inspire-prototype`
   - Feature-level work → `/inspire-feature`
   - ADR misalignment → `/inspire-adr`
   - Exposure (which bundle publishes the module) → `/inspire-face`
   - Global / vault concerns → `/inspire-workspace`
7. **Stamp every write.** After `create`, `update`, or `delete` writes the hub,
   run `.inspire/bin/trust.sh stamp <file> --skill module`
   ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting a hub
   that carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).
