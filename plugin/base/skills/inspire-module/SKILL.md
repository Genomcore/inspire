---
name: inspire-module
description: "Lifecycle of a module and its 02_modules hub: create / review / update / scan / delete a module and propagate across the KB layers it links (features, screens, specs, spikes, ADRs). Use when scaffolding a new module, auditing one before a PR, authoring its specs, or removing it."
---

# /inspire_module — Module-level Operations

## Scope

A **module** is the organizing unit of the product. Its **hub** is
`inspire_kb/02_modules/{module}.md` — the second-level artifact (after `00_bootstrap`):
overview, relationships to other modules, and links to everything the module owns
across the layers. Its use cases live in `inspire_kb/03_features/{module}/` (**one
file per use case**). This skill owns the hub and its propagation across the KB
layers it links: features (`03_features`), screen specs (`05_screens`), the prototype
(`/prototype`), specs (`04_domain`), spikes (`06_spikes`), and ADRs (`01_adr`). The
per-layer subfolders stay **in sync** with the hub — that is this skill's core
invariant.

## Invocation

- `/inspire_module review {module}` — full consistency review before PR
- `/inspire_module create {module}` — scaffold a new module across the layers
- `/inspire_module update {module}` — add/remove use cases, restructure, propagate
- `/inspire_module scan {module}` — SDD-layer entry point (surface + author specs)
- `/inspire_module delete {module}` — remove the module and clean every cross-reference

## Subcommands in `references/`

Every subcommand's full procedure lives in a reference file. **Before executing
any subcommand, read every reference file its index row names** — the table
below is an index, not the flow.

| Subcommand | What it does |
|---|---|
| [`review`](references/module-review.md) | Full consistency review before any PR that modifies the hub or its features |
| [`create`](references/module-edits.md) | Scaffold a new module across the layers |
| [`update`](references/module-edits.md) | Add/remove use cases, restructure, propagate |
| [`scan`](references/module-scan.md) | SDD-layer entry point — surface candidates and chain into `/inspire_domain` |
| [`delete`](references/module-edits.md) | Remove the module and clean every cross-reference |

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, wikilink slugs, filenames)
> stay verbatim.

> **Writing contract.** Module hubs follow
> [`_references/writing-style.md`](../_references/writing-style.md). `## Overview` and
> `## Relationships` are normative prose (R1–R6); the `## Use cases`, `## Screens`,
> `## Domain` and `## Module ADRs` tables are structured sections (R3, R4, R6).
> Referenced, never restated — read the rules there.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire_lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **`review` is read-only.** It reports, suggests fixes, and recommends other
   skills; it never edits files.
2. **`create` requires user input** for module name, ID prefix, and description.
3. **`update` and `delete` require an explicit plan** presented to the user before
   any edit.
4. **Hub ↔ layers stay in sync.** The `02_modules/{module}.md` hub and its per-layer
   subfolders (`03_features`, `05_screens`, `04_domain`) must agree — a module
   operation that updates one but leaves the others inconsistent is a bug. This is
   the skill's core invariant; `review` enforces it.
5. **Pending drift is acceptable.** Drift items in `## Current prototype` sections
   are informational; don't block PRs unless they contradict a current ADR (one not
   superseded or rejected).
6. **Consult the task tracker** at the start of each invocation
   (`/inspire_task list`). Known items in
   `inspire_kb/99_tracker/tickets/` are surfaced as `(tracked: TASK-{id})`.
7. **Actionable findings.** Every issue names the skill to invoke for the fix:
   - screen spec drift → `/inspire_screens`
   - Prototype drift → `/inspire_prototype`
   - Feature-level work → `/inspire_feature`
   - ADR misalignment → `/inspire_adr`
   - Global / vault concerns → `/inspire_workspace`
8. **Stamp every write.** After `create`, `update`, or `delete` writes the hub,
   run `.inspire/bin/trust.sh stamp <file> --skill module`
   ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting a hub
   that carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).
