---
name: inspire-adr
description: "ADR lifecycle for architectural decisions at three scopes, set by placement (global, one module, one face): create / update / promote / supersede / migrate along a maturity ladder (design → prototyped → implemented). Use when proposing, recording, advancing, or retiring an architectural decision."
---

# /inspire-adr — Architecture Decision Records

## Scope

An **ADR** records an architectural decision. Where its files sit is its scope:

| Scope | Directory | Holds |
|---|---|---|
| **Global** | `inspire_kb/01_spec/_adr/` | a decision that spans **≥2 modules or ≥2 faces**, or is system-wide |
| **Module** | `inspire_kb/01_spec/_modules/{module}/_adr/` | a decision that binds one module |
| **Face** | `inspire_kb/01_spec/_faces/{face}/_adr/` | a decision that binds one face, even when it spans two modules within that face |

Nothing else declares the scope. Tools find every ADR by its extension, `*.adr.md`,
wherever it sits under `inspire_kb/01_spec/`. This skill owns their full
lifecycle. It does **not** run the global review — [`/inspire-workspace review`](../inspire-workspace/SKILL.md)
checks that an ADR's consequences have actually propagated; this skill authors and
advances the decisions themselves.

An ADR is the **decision rung** of the authority ladder
([`_references/authority.md`](../_references/authority.md)). A rule binding one
module belongs in that module's hub, and one binding a single use case, descriptor or
screen belongs in that artifact — each of those outranks an ADR on the question it
actually decides. The reverse is the usual reason to open an ADR: the same departure
declared in a third artifact is a decision sitting at the wrong rung, and it belongs
here.

## The maturity ladder

ADR `Status` is a **maturity ladder**, not a binary — it declares how far the
decision has been realized, and therefore how far its consequences should have
propagated (the *propagation contract*):

- `design` — design reasoning. Reach: the whole **design workspace** — features
  (`*.feature.md`) + screens (`*.screen.md`) + the **horizontal prototype**
  (`/prototype` by default, a *non-functional* interactive mock — resolve
  `prototype_root` per
  [`_references/product-roots.md`](../_references/product-roots.md), where `none`
  means this project has no horizontal prototype for a decision to reach) + specs
  (`*.entity.md`, `*.action.md`). Refined **in place** on new evidence.
- `prototyped` — additionally **validated in an external functional prototype**:
  real running code in a vertical spike repo has proven the architecture works
  (record it with a `**Prototype:**` pointer to that repo). The horizontal
  prototype does **not** count. Still refined in place.
- `implemented` — additionally realized in the **product codebase**. **Immutable —
  both files of the pair; `supersede` to change.**
- `superseded` (by [[x]]) / `rejected` — terminal.

There is no `proposed`/`accepted` state: an ADR present and not
superseded/rejected **is** the current decision at its maturity; the debate
happens in chat before authoring.

## Invocation

- `/inspire-adr create {slug}` — new ADR (defaults to `Status: design`)
- `/inspire-adr update {id}` — modify an ADR (supersede required only at `implemented`)
- `/inspire-adr promote {id} {maturity}` — advance maturity and propagate consequences
- `/inspire-adr supersede {id} {new-id}` — mark old ADR superseded and wire the wikilink
- `/inspire-adr migrate [{id}…]` — split single-file ADRs into a decision and a rationale

## The decision and its rationale

Every ADR is a pair of files that share one slug, side by side in the same `_adr/`:

- **`{slug}.adr.md` — the decision.** The H1 title, `**Status:**`,
  `**Modules affected:**`, `**Rationale:** [[adr-{slug}.rationale]]`, any `Supersedes:`
  or `**Prototype:**` line, on a global ADR the `faces:` / `bundles:` frontmatter, and
  `## Decision`: one or a few imperative statements ("Authentication uses the Better
  Auth library."). It binds, so
  it stays short: the session-start hook injects every live decision into every
  session, through `.inspire/bin/decisions.sh`.
- **`{slug}.adr.rationale.md` — the rationale.** `**Decision:** [[adr-{slug}]]`, then
  `## Context`, `## Consequences` (with `### Breaking changes`),
  `## Alternatives considered` and `## Related ADRs`. It explains the decision and
  constrains nothing, so it is read only when someone questions or supersedes it.

The test for a sentence in `## Decision`: would a reader who follows it build
something different without it? If not, it is a reason, and it belongs in the rationale.
A `[[adr-{slug}]]` wikilink always means the decision; link the rationale by its own
name only when the reasons are the point.

## Subcommand: create {slug}

### Conventions

- **Filename:** `{slug}.adr.md` for the decision and `{slug}.adr.rationale.md` beside
  it for the rationale. Slug-only — no numeric prefix, and no `adr-` prefix: the
  extension already says the file is an ADR.
- **Location is the scope:** the global `_adr/`, the module's `_adr/` or the face's
  `_adr/` (see [Scope](#scope)). A module ADR's slug does not repeat the module's
  name or prefix: its placement says the module. Which scope a write takes resolves
  per [`_references/face-scope.md`](../_references/face-scope.md) § Scope resolution:
  an explicit argument wins, and the skill asks when nothing pins it.
- **Slug uniqueness:** unique across the project, whatever the scope.
  `spec-identity.sh` reports a duplicate.
- **Canonical ID:** `adr-{slug}`, the prefix added back to the slug when the id is
  read. The rationale's id is `adr-{slug}.rationale`. The H1 is the human title, and
  the rationale's H1 is the same title followed by `— rationale`.
- **Blast radius:** a **global** ADR carries the `faces:` / `bundles:` frontmatter
  the template below holds; absent means the whole project. A module or face ADR
  carries neither: its placement gives the scope. `**Modules affected:**` lists the
  modules either way. Semantics — what an absent field means and how an id resolves
  — live in [`_references/face-scope.md`](../_references/face-scope.md) and are not
  restated here.

**Rationale.** Numeric prefixes collide under parallel work (two branches grab the
same next number). Slug-only filenames are collision-free by construction
(mirroring the `TASK-{id}` convention).

### Exposure lives in bundles

*Which service exposes which modules* is not an ADR. It is expressed by
**bundles**: each `{bundle}.bundle.md` lists, under `## Actions`, the whole modules
(`[[tenancy]] (whole module)`) and the single actions it exposes, with its package
and profiles. [`/inspire-face`](../inspire-face/SKILL.md) owns the bundle files. The
domain stays a single untagged truth: no entity or action names a bundle. Overlap is
allowed — an action may sit in two bundles. A project with one bundle exposing
everything still has that one bundle file.

When the reasons for a split are worth recording ("the admin API is its own bundle
because it runs inside the operator network"), write a global ADR with
`bundles:` naming the bundles it concerns. The ADR states the reasons and links the
bundles; it never restates their `## Actions` lists.

Action-granular pressure — most of one module's actions splitting across bundles —
is a modularity smell: split the module (`inspire-module`) rather than list its
actions one by one. A backend for a frontend is a bundle with an artifact of its own.

### The action-verbs ADR

A named pattern for the project's **action verbs**: the last segment of every
action id. The verbs come from the application's own domain (a library reserves,
cancels and picks up a book), and they are one system-wide decision, recorded in one
ADR with the fixed id **`adr-action-verbs`**. `/inspire-domain` reads it whenever it
lands an action's verb, and falls back to its default set (`list` · `get` ·
`create` · `edit` · `delete`) while the ADR does not exist.

The ADR lists each verb with the kind of change it names, and any rule attached to a
kind of verb (an event every mutation emits, timestamps every mutable entity
carries). It does not restate the generic rules in
[`inspire-domain/references/interview-prompts-action.md`](../inspire-domain/references/interview-prompts-action.md):
one target object per action, plural verbs for reads that return many, singular
verbs for reads that return one. A new verb is added here before the descriptor
that uses it lands.

### Template

Templates: [`templates/adr.template.md`](templates/adr.template.md) for the decision
and [`templates/adr.rationale.template.md`](templates/adr.rationale.template.md) for the
rationale — the decision's `Supersedes:` header line is optional (add only when superseding, per the
`supersede` subcommand below); the `faces:` / `bundles:` frontmatter is for a global
ADR only and defaults to the whole project by omission, per
[`_references/face-scope.md`](../_references/face-scope.md).

### Steps

1. **Ask** the user: short title, scope (global, a module or a face — see
   Conventions), modules affected, for a global ADR the blast radius (the `faces:` /
   `bundles:` fields; with exactly one face and one bundle there is nothing to ask),
   context, the decision, key consequences, alternatives considered.
2. **Write both files** in the scope's `_adr/`: `{slug}.adr.md`, then
   `{slug}.adr.rationale.md`. Keep every reason out of `## Decision` (see [the
   decision and its rationale](#the-decision-and-its-rationale)).
3. **Create every missing link target.** A link to something that does not exist yet
   requires its file. For each `[[…]]` the two files write (`**Modules affected:**`,
   `## Related ADRs`, a face or bundle in the frontmatter) whose target is missing,
   create it from its template in draft: a module hub from
   [`inspire-module`'s template](../inspire-module/templates/module.template.md), an ADR
   from [`templates/adr.template.md`](templates/adr.template.md) at `**Status:** design`,
   a face or bundle from `inspire-face`'s templates at `lifecycle: draft`. Name each one
   in the output.
4. **Propose ADR references** in the feature files that should link to it: list
   files to edit, wait for approval.
5. Set `**Status:** design` by default. Use `promote` later to advance.

## Subcommand: update {id}

Modify an ADR in place. At `design` / `prototyped` maturity this is the **normal
path** — freely edit either file, including `Decision`; record new evidence (e.g. a
`**Prototype:**` pointer) when it drove the change.

**At `Status: implemented`** both files are frozen: a change to either one requires
`supersede` (product code depends on the decision, and the reasons it was taken are
part of the audit trail): present a warning and offer to switch approach. `migrate`
is the one exception, because it moves text without changing it. `supersede` also
stays available at any maturity for a genuine reversal you want recorded as a
distinct decision.

When the ADR is still in the single-file shape, offer `migrate` for it first.

## Subcommand: promote {id} {maturity}

Advance an ADR along `design → prototyped → implemented` and propagate its
consequences to the layers the new maturity reaches.

1. Verify the ADR exists and the transition is a **forward** step. Reject skips and
   downgrades — refine the `Decision` in place with `update` instead.
2. Update `**Status:** {maturity}` in the decision file. For `prototyped`, require a
   `**Prototype:**` pointer (which external repo validated it, and the evidence); for `implemented`,
   note where in the codebase it lives.
3. **Propagate / record evidence:** confirm the design workspace reflects the
   decision, then for each affected module invoke `/inspire-module review {module}`
   to detect where the ADR's consequences are not yet reflected. Surface the gaps
   as follow-up actions.
4. **Propose endorsement.** Ask the operator whether to endorse the promoted
   decision, then separately whether to endorse its rationale; on each explicit yes,
   run `.inspire/bin/trust.sh endorse <file>` on that file
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).

## Subcommand: supersede {id} {new-id}

Replace an ADR with a new one that changes its decision (create the new ADR first
via `create`).

1. Verify both ADRs exist (the old one at any non-terminal maturity).
2. Update the old decision file: `**Status:** superseded by [[{new-id}]]`. Its
   rationale stays as it is.
3. Update the new decision file's header: `Supersedes: [[{old-id}]]`.
4. Search `inspire_kb/` for links to the old ADR (`[[{old-id}]]`); propose updates.

## Subcommand: migrate [{id}…]

Split ADRs written before the pair existed: one file holding all five sections. With
no ids it takes every single-file ADR: every `*.adr.md` under `inspire_kb/01_spec/`
with no rationale beside it. A project's KB is the
operator's, so an upgrade never runs this on its own: `/inspire:update` offers it, and
the operator runs it.

1. **List.** Run `.inspire/bin/adr-split.sh --list` (or with the ids' paths). Nothing
   listed means nothing to do.
2. **Disclose.** For each listed file carrying `endorsed:`, say that the split rewrites
   content that person endorsed, and on which date
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).
3. **Split.** Run `.inspire/bin/adr-split.sh` on the listed paths. It moves every line
   verbatim: the frontmatter, the header and `## Decision` stay in `{slug}.adr.md`, a
   `**Rationale:**` link joins the header, and every other section moves, in order, to
   `{slug}.adr.rationale.md` beside it. It reports one line per file: `split`, or `skipped` for a
   file with no `## Decision` section. Write that section with the operator for each
   skipped file, then run the script on it again.
4. **Trim each decision.** The old template asked `## Decision` for "what we decided
   and why", so many of them carry reasons. For each split ADR, read `## Decision`
   and show the operator the sentences that fail the test in [the decision and its
   rationale](#the-decision-and-its-rationale), with the proposal to move them, word
   for word, to the end of the rationale's `## Context`. Move them on a yes. This
   step changes no word either, so it is allowed at `implemented` too. A decision
   whose every sentence binds needs no question.
5. **Stamp** both files of every pair (rule 6 below). Propose no endorsement:
   nothing was decided.

## Rules

> **Output language.** Write every ADR in the project's declared `output_language`
> (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in; machine-read tokens (frontmatter
> keys/values, wikilink slugs, filenames) stay verbatim.

> **Writing contract.** ADR prose follows
> [`_references/writing-style.md`](../_references/writing-style.md). `## Decision` in
> the decision file and `## Context`, `## Consequences` and `## Alternatives considered`
> in the rationale are normative prose
> (R1–R6); `**Modules affected:**` and any tabular section are structured (R3, R4, R6).
> R6 carries section-scoped exemptions this skill relies on — see the
> *no historical language* rule below.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **Maturity is explicit, and only `implemented` is immutable.** `create` defaults
   to `design` and `promote` is the only way forward; a `design` / `prototyped` ADR
   is refined in place with `update`, while changing either file of an `implemented`
   ADR requires `supersede`.
2. **Propagate to the maturity's reach.** Design-workspace coherence (features +
   screen spec + horizontal prototype + specs) is required at every maturity;
   `prototyped` adds a pointer to an external functional prototype, `implemented` a
   codebase reference. Surface gaps within that reach.
3. **Grep references on rename/supersede.** Always scan the vault when renaming an
   ADR or changing its ID.
4. **No historical language, per the writing contract.** R6 of
   [`_references/writing-style.md`](../_references/writing-style.md): an ADR describes
   the decision context, never a migration narrative. This rule is **deliberately
   narrower than unconditional** — the contract exempts `### Breaking changes`
   content, `## Related ADRs`, the `**Status:**` line and a `Supersedes:` header,
   because this skill mandates those sections and a ban on their content would ban a
   required section.
5. **Consult the task tracker** ([`/inspire-task list`](../inspire-task/SKILL.md))
   for tracked items; don't re-open what's already ticketed.
6. **Check and stamp every write.** After an ADR file is written — the
   decision, the rationale, or both — run `.inspire/bin/review.sh <file>` on
   each one and fix what it reports on that file: every error, and every
   warning the operator does not choose to keep
   ([write-checks](../_references/write-checks.md)). Then run, for each one,
   `.inspire/bin/trust.sh stamp <file> --skill adr`
   ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting an ADR
   that carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).

## Related skills

- `/inspire-workspace` — the global review checks ADR-propagation alignment (that
  consequences cohere across the design workspace within each ADR's maturity reach).
- `/inspire-module` — `promote` propagates by invoking module review to surface
  where an ADR's consequences aren't yet reflected.
