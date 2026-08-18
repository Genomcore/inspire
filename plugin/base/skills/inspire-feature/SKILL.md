---
name: inspire-feature
description: "Lifecycle of a feature / use case: create / review / update / scan / delete a use-case file in a module and propagate across the KB layers. Use when adding, auditing, or removing features."
---

# /inspire_feature — Feature-level Operations

## Scope

A **feature** is a use case, captured as a file
`inspire_kb/03_features/{module}/{use-case}.md`, linked from that module's hub
`02_modules/{module}.md`. This skill owns feature-scoped operations and their propagation
across the KB layers: screens (`05_screens`), prototype (`/prototype` by default —
resolve `prototype_root` per
[`_references/product-roots.md`](../_references/product-roots.md)), specs
(`04_domain`), and ADRs (`01_adr`).

## Invocation

- `/inspire_feature review {feature-id}` — single feature, all layers
- `/inspire_feature review {module}` — batch mode, all features of a module (parallel agents)
- `/inspire_feature create {module}/{feature-id}` — new use-case file
- `/inspire_feature update {feature-id}` — modify description, dependencies, priority
- `/inspire_feature delete {feature-id}` — remove + orphan checks across layers
- `/inspire_feature scan {feature-id}` — SDD layer alignment for one feature (fast)
- `/inspire_feature scan {module}` — batch SDD layer alignment for all features of a module

## Subcommands in `references/`

Every subcommand's full procedure lives in a reference file. **Before executing
any subcommand, read every reference file its index row names** — the table
below is an index, not the flow.

| Subcommand | What it does |
|---|---|
| [`review`](references/feature-review.md) | Review one feature across all KB layers, or batch-review every feature of a module in parallel |
| [`scan`](references/feature-scan.md) | SDD-layer entry point — surface candidate actions and chain into `/inspire_domain` |
| [`create`](references/feature-edits.md) / [`update`](references/feature-edits.md) / [`delete`](references/feature-edits.md) | New use-case file / modify description, dependencies, priority / remove + orphan checks across layers |
| [acceptance-criteria gate](references/feature-ac-gate.md) | Judgment gate for `## Acceptance criteria` — run inline by `create` and `update`, not a subcommand of its own |

## Use case template

Use this template at `inspire_kb/03_features/{module}/{feature-id}.md`. Its
frontmatter declares the feature's **blast radius** — the surfaces this use case
affects. What an absent field means, when the field becomes mandatory and how a
surface id resolves are defined in
[`_references/surface-scope.md`](../_references/surface-scope.md); read them
there, they are not restated here.

Template: [`templates/use-case.md.template`](templates/use-case.md.template) —
description, the `**State:**` / `**Priority:**` / `**Depends on:**` lines, and the
acceptance-criteria id contract are documented there.

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, wikilink slugs, filenames)
> stay verbatim.

> **Writing contract.** Use-case files follow
> [`_references/writing-style.md`](../_references/writing-style.md). `## Preconditions`,
> `## Main flow`, `## Alternative flows`, `## Error flows` and `## Postconditions` are
> normative prose (R1–R6). `## Acceptance criteria` binds R1–R4 and R6, and each
> criterion states an observable outcome — no *fast*, *intuitive*, *appropriate*.
> Referenced, never restated — read the rules there.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire_lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **The use-case file is the source of truth.** Everything else (screen spec,
   prototype, specs) references or realizes it.
2. **One file per use case.** The filename matches the feature ID.
3. **Use cases are functional, not technical.** They describe WHAT from the user's
   perspective, not HOW — no SQL, no API paths, no component names.
4. **`review` is read-only.** `update` / `delete` require user approval of the plan
   before writing; `create` gathers its inputs from the operator and runs the
   acceptance-criteria gate before writing.
5. **Propagation is mandatory.** Deleting or renaming a feature without cleaning
   references is drift.
6. **N/A is valid.** Not every feature needs every layer — infrastructure features
   may have no UI.
7. **Drift is informational.** `## Current prototype` drift items don't block
   reviews unless they contradict a current ADR (one not superseded or rejected).
8. **Consult the task tracker** (`/inspire_task list`) for tracked drift; don't
   re-surface it as new.
9. **Acceptance criteria pass the quality gate before they land.** `create` and
   `update` run it inline — what the gate checks, and what a criterion that cannot
   be made testable means, are
   [`references/feature-ac-gate.md`](references/feature-ac-gate.md)'s.
10. **Stamp every write.** After `create`, `update`, or `delete` writes the
    use-case file, run `.inspire/bin/trust.sh stamp <file> --skill feature`
    ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting one
    that carries `endorsed:` is disclosed to the operator first
    ([trust-stamps](../_references/trust-stamps.md#endorsement)).
