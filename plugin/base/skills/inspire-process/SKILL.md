---
name: inspire-process
description: "Lifecycle of a process — system behaviour no actor invokes directly (a scheduled job, a token refresh, the first population of the database): create / update / review a {process}.process.md at global, module or face level. Use when the product must do something on a schedule, on an event or at start-up, with nobody asking for it."
---

# /inspire-process — Processes

## Scope

A **process** is behaviour the system runs on a trigger instead of a person's
request: a schedule, an event, start-up, or another process. A nightly report, a
token refresh, the first load of reference data. It calls actions, in order, and
changes domain only through them.

A process is captured as one file, `{process}.process.md`, with
`id: {scope}.{process}`. The scope says where it lives:

| Scope | `{scope}` in the id | Placement |
|---|---|---|
| Global | `global` | `inspire_kb/01_spec/_processes/` |
| A module | the module id | `inspire_kb/01_spec/_modules/{module}/_processes/` |
| A face | the face id | `inspire_kb/01_spec/_faces/{face}/_processes/` |

Pick the narrowest scope whose domain the process touches: a process that only
calls one module's actions is that module's; a face-level process (an interceptor,
a session refresh) runs inside one application; a process that spans modules is
global. Tools find a process by its `.process.md` extension and resolve it by id,
never by directory, so the placement is for people — but it must agree with the id.

This skill owns every `*.process.md` under `inspire_kb/01_spec/`. It does not own
the actions a process calls (`inspire-domain`), the module or face it is scoped to
(`inspire-module`, `inspire-face`), or a person-driven use case (`inspire-feature`):
if an actor starts it, it is a feature, not a process.

## Invocation

- `/inspire-process create {scope}/{process}` — new process file
- `/inspire-process update {process-id}` — change its trigger, actions, steps or affects
- `/inspire-process review {process-id}` — one process (read-only)
- `/inspire-process review {scope}` — every process of a module, a face, or `global`

## Process template

Template: [`templates/process.template.md`](templates/process.template.md).

| Section | What it holds |
|---|---|
| `## Trigger` | What starts it: a schedule, an event (an action succeeding, a message arriving), start-up, or another process. Exactly one trigger. |
| `## Requires` | The actions it calls, as wikilinks `[[{module}.{entity}.{action}\|{module}::{entity}::{action}]]`. Dependencies, not claims: each action is tested as its own unit. |
| `## Before` | Its pre-actions, in order — what must run before the steps. `None.` when there are none. |
| `## Behaviour` | Its steps, keyed `B{n}`, in the order they run. |
| `## After` | Its post-actions, in order. `None.` when there are none. |
| `## Affects` | The entities it changes, as wikilinks `[[{module}.{entity}\|{module}::{entity}]]`. |

**Claims.** The INSPIRE Factory derives one claim for the trigger
(`{process}/trigger`), one per `B{n}` step, and one per pre-action and post-action,
so their order is tested. `## Requires` and `## Affects` produce no test of their
own: the first is the unit's dependencies, the second is checked against what the
required actions touch.

`B{n}` keys follow the contract in
[`_references/keyed-heads.md`](../_references/keyed-heads.md): write-once, never
renumbered, never reused. Deleting a step leaves a gap.

## Subcommand: create

1. **Confirm it is a process.** Ask what starts it. If the answer is a person, stop
   and offer `/inspire-feature` instead.
2. **Settle the scope** with the operator, from the table above. The module or face
   must exist as a `*.module.md` or `*.face.md`; a scope with no file is an error,
   not an invitation to create one here.
3. **Validate the id** — `{scope}.{process}`, the process name a slug that never
   starts with `_`, unique in the project.
4. **Interview the sections** in template order: trigger, required actions,
   pre-actions, steps, post-actions, affected entities. State each step as one
   observable thing the system does.
5. **Every link has a file.** An action in `## Requires`, `## Before` or `## After`,
   or an entity in `## Affects`, that does not exist yet is created as a draft from
   its template (`inspire-domain`'s `action.template.md` or `entity.template.md`)
   with `lifecycle: draft`, in the same change.
6. **Write the file** at the placement the scope names, from the template, with
   `lifecycle: draft`.
7. **Offer the link back.** A module-scoped process is worth naming from the
   module's hub; offer the edit to `/inspire-module`, never apply it here.

## Subcommand: update

1. **Read the file and present the plan** — which sections change and why — before
   writing. The operator approves it.
2. **Keys are write-once.** A new step takes the next free `B{n}`; a removed step
   leaves its gap. A change of meaning is a new key, not an edit of an old one.
3. **Moving scope changes the id.** A process moved from a module to `global` is
   `global.{process}`: move the file, rewrite the links to it, and tell the operator
   that a process the Factory has built is cited by its old id.
4. **Every new link has a file**, as in `create`.

## Subcommand: review

Read-only. It reports, recommends and offers; it never edits.

1. **Run the validator:**

   ```bash
   .inspire/bin/process-shape.sh {path}
   ```

   It checks that `## Trigger` holds something, that `## Requires` links at least
   one action, that every entity in `## Affects` is touched by one of the required
   actions, and that the id is `{scope}.{process}` with scope `global`, a module or
   a face.
2. **Add the judgment the validator cannot make:**
   - **Is it really a process?** A trigger that is a person's click is a feature.
   - **Is the scope the narrowest one?** A global process that only calls one
     module's actions belongs to that module. A module process whose id scope and
     placement disagree is a finding.
   - **Is the trigger testable?** A schedule names its cadence and timezone; an
     event names the action or message that raises it.
   - **Do pre- and post-actions and steps agree?** Each `B{n}` that calls an action
     names one in `## Requires`; each pre- and post-action is in `## Requires` too.
   - **What happens on failure?** A step that can fail and states no outcome is a
     gap worth a question.

Render findings in the shared operator-facing format from
[`_references/findings-format.md`](../_references/findings-format.md). Validator
findings name their rule; the judgment checks name the check in the rule slot.

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, wikilink slugs, filenames)
> stay verbatim.

> **Writing contract.** Process files follow
> [`_references/writing-style.md`](../_references/writing-style.md). `## Trigger`
> and `## Behaviour` are normative prose (R1–R6). Referenced, never restated.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **A process has nobody behind it.** If a person starts it, it is a feature.
2. **A process changes domain only through actions.** It never writes an entity
   directly, and `## Affects` names only what its actions touch.
3. **One file per process.** The file name is the process slug; the id is
   `{scope}.{process}`, and placement agrees with the scope.
4. **`review` is read-only.** `update` requires the operator's approval of the plan
   before writing.
5. **Every link has a file.** A missing target is created as a draft from its
   template in the same change.
6. **Check and stamp every write.** After `create` or `update` writes the process
   file, run `.inspire/bin/review.sh <file>` and fix what it reports on that file:
   every error, and every warning the operator does not choose to keep
   ([write-checks](../_references/write-checks.md)). Then run
   `.inspire/bin/trust.sh stamp <file> --skill process`
   ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting one that
   carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).

## Related skills

- `/inspire-domain` — owns the actions and entities a process requires and affects.
- `/inspire-module` — the module a module-scoped process belongs to.
- `/inspire-face` — the face a face-scoped process belongs to.
- `/inspire-feature` — person-driven use cases; a process is what is left when no
  person is involved.
- `/inspire-workspace` — the global pre-PR review runs `process-shape.sh` over the KB.
