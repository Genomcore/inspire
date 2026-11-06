---
name: inspire-feature
description: "Lifecycle of a feature / use case: create / review / update / scan / delete a use-case file in a module and propagate to the screens, specs and ADRs that cite it. Use when adding, auditing, or removing features."
---

# /inspire-feature — Feature-level Operations

## Scope

A **feature** is a use case, captured as a file
`inspire_kb/01_spec/_modules/{module}/_features/{use-case}.feature.md`, linked from
that module's hub `_modules/{module}/{module}.module.md`. Its id is the file name
without the extension, `{use-case}`. This skill owns feature-scoped operations and
their propagation to every artifact that cites a feature: screens (`*.screen.md`, in
the faces), prototype (`/prototype` by default — resolve `prototype_root` per
[`_references/product-roots.md`](../_references/product-roots.md)), specs
(`*.entity.md`, `*.action.md` in the module's `_domain/`), and ADRs (`*.adr.md`).
Tools find features by extension, never by directory: every `*.feature.md` under
`inspire_kb/01_spec/`, or under one module's directory.

## Invocation

- `/inspire-feature review {feature-id}` — single feature, all layers
- `/inspire-feature review {module}` — batch mode, all features of a module (parallel agents)
- `/inspire-feature create {module}/{feature-id}` — new use-case file
- `/inspire-feature update {feature-id}` — modify description, dependencies, priority
- `/inspire-feature delete {feature-id}` — remove + orphan checks across layers
- `/inspire-feature scan {feature-id}` — SDD layer alignment for one feature (fast)
- `/inspire-feature scan {module}` — batch SDD layer alignment for all features of a module

## Subcommands in `references/`

Every subcommand's full procedure lives in a reference file. **Before executing
any subcommand, read every reference file its index row names** — the table
below is an index, not the flow.

| Subcommand | What it does |
|---|---|
| [`review`](references/feature-review.md) | Review one feature across all KB layers, or batch-review every feature of a module in parallel |
| [`scan`](references/feature-scan.md) | SDD-layer entry point — surface candidate actions and chain into `/inspire-domain` |
| [`create`](references/feature-edits.md) / [`update`](references/feature-edits.md) / [`delete`](references/feature-edits.md) | New use-case file / modify description, dependencies, priority / remove + orphan checks across layers |
| [acceptance-criteria gate](references/feature-ac-gate.md) | Judgment gate for `## Acceptance criteria` — run inline by `create` and `update`, not a subcommand of its own |

## Use case template

Use this template at
`inspire_kb/01_spec/_modules/{module}/_features/{feature-id}.feature.md`. Its
frontmatter declares the feature's **blast radius** — the faces (`faces:`) and
bundles (`bundles:`) this use case affects; absent means the whole project. How an
id resolves is defined in
[`_references/face-scope.md`](../_references/face-scope.md); read it there, it is
not restated here.

Template: [`templates/feature.template.md`](templates/feature.template.md) —
description, the `**State:**` / `**Priority:**` / `**Depends on:**` lines, and the
acceptance-criteria id contract are documented there.

Three sections carry **keyed entries**: `## Preconditions` (`P{n}`),
`## Main flow` (`B{n}`) and `## Postconditions` (`Q{n}`), joining the `AC-{n}`
contract acceptance criteria already carry. The entry grammar, the optional
machine-readable heads and their closed vocabularies live in
[`_references/keyed-heads.md`](../_references/keyed-heads.md) — read them there,
they are not restated here. What matters at feature altitude: keys are
write-once and never renumbered (deleting a step leaves a gap, which is the
contract working), and most use-case entries are legitimately **prose-only** —
a use case describes what from the user's perspective, and a head that does not
fit exactly is worse than no head.

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
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **The use-case file is the source of truth.** Everything else (screen spec,
   prototype, specs) references or realizes it.
2. **One file per use case.** The filename is the feature ID plus `.feature.md`.
3. **Use cases are functional, not technical.** They describe WHAT from the user's
   perspective, not HOW — no SQL, no API paths, no component names.
4. **`review` is read-only.** `update` / `delete` require user approval of the plan
   before writing; `create` gathers its inputs from the operator and runs the
   acceptance-criteria gate before writing.
5. **Propagation is mandatory.** Deleting or renaming a feature without cleaning
   references is drift.
6. **A link requires its target.** When a write links to something that does not
   exist yet (a `**Depends on:**` feature, an ADR, the module hub), create the target
   from its template in draft and name it in the output: a feature from
   [`templates/feature.template.md`](templates/feature.template.md) at
   `**State:** 🟡 Planned`, an ADR from
   [`inspire-adr`'s template](../inspire-adr/templates/adr.template.md) at
   `**Status:** design`, a face or bundle from `inspire-face`'s templates at
   `lifecycle: draft`.
7. **N/A is valid.** Not every feature needs every layer — infrastructure features
   may have no UI.
8. **Drift is informational.** `## Current prototype` drift items don't block
   reviews unless they contradict a current ADR (one not superseded or rejected).
9. **Consult the task tracker** (`/inspire-task list`) for tracked drift; don't
   re-surface it as new.
10. **Acceptance criteria pass the quality gate before they land.** `create` and
    `update` run it inline — what the gate checks, and what a criterion that cannot
    be made testable means, are
    [`references/feature-ac-gate.md`](references/feature-ac-gate.md)'s.
11. **Check and stamp every write.** After `create`, `update`, or `delete`
    writes the use-case file, run `.inspire/bin/review.sh <file>` and fix what
    it reports on that file: every error, and every warning the operator does
    not choose to keep ([write-checks](../_references/write-checks.md)). Then
    run `.inspire/bin/trust.sh stamp <file> --skill feature`
    ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting one
    that carries `endorsed:` is disclosed to the operator first
    ([trust-stamps](../_references/trust-stamps.md#endorsement)).
