---
name: inspire-config
description: "Configure the project: the spec config .inspire/config.json (product roots and output language), the project's identity, the default theme, the tech stack in stack.md, and .inspire/emanate.yml, the file that tells INSPIRE Factory which image, services, environment, setup and checks every unit runs with. Its wizard separates product questions from technical ones, and every technical question can keep the shipped default. Use right after /inspire:init, when setting the language, choosing the target and the stack, changing a stack choice, preparing a project for its first factory run, or when the factory refuses the file. Operator work only: never part of coding a unit."
argument-hint: "init|language|identity|theme|stack|emanate|review"
user-invocable: true
---

# /inspire-config — The project's configuration

## Scope

INSPIRE ships a default for every value this skill owns, so a project authors specs
before anyone answers a question here. The skill changes those defaults. Two people
answer it:

- the **functional operator** specifies the product, and answers the **product**
  questions: language, identity, theme;
- the **technical operator** reviews and builds it, and answers the **technical**
  questions: target, stack, product roots, the factory's file.

**Owns:**

- `.inspire/config.json`, the **spec config**: `source_root`, `prototype_root` and
  `output_language` ([`references/spec-config.md`](references/spec-config.md)).
- The bootstrap layer, `inspire_kb/00_bootstrap`: `project.md`, `stack.md`,
  `glossary.md` and `style-tokens.md`. `semantic-types.md` ships empty and no
  interview here fills it: a type is declared when domain work meets a field the
  universal vocabulary
  ([`type-mapping.md`](../inspire-domain/references/type-mapping.md)) has no type for.
- `theme.md` and `theme.tokens.json` in `inspire_kb/01_spec/_design-system`, the
  design-system default.
- The project's identity: the root `README.md` and the placeholders of the seeded
  `CLAUDE.md`.
- `.inspire/emanate.yml`, the file **INSPIRE Factory** reads to run the project, its
  `factory` section included: the Factory's own settings (`kb_root`, `spec_root`,
  `model`, `review_model`, `subagent_models`, `concurrency`, `check_concurrency`,
  `max_tries`, `spec_strictness`, `spec_max_revisions`, `spec_classifier_model`,
  `base_branch`, `viewer_port`, `sandbox`). The Factory is the separate service that
  runs emanation in containers, and it stops a run without this file.

**Does NOT own:**

- The live design system, `design-system.md` and `design-system.tokens.json`. They
  are seeded from the theme at install and belong to
  [`/inspire-screens design-system`](../inspire-screens/SKILL.md).
- Faces and bundles. `/inspire-face` writes every `{face}.face.md` and
  `{bundle}.bundle.md`.
- The skills and files a `review` check of `emanate.yml` names. The check points at
  them; it never writes them.
- Starting services, or any container left running.
- The commit. The operator commits what this skill writes; the skill says where.

## Invocation

| Subcommand | Kind | What it does |
|---|---|---|
| `/inspire-config init` | both | the wizard: the product questions, then the technical ones, each optional ([`references/wizard.md`](references/wizard.md)) |
| `/inspire-config language` | product | set `output_language` in the spec config ([`references/spec-config.md`](references/spec-config.md) § Changing the language) |
| `/inspire-config identity` | product | the root `README.md` and the `CLAUDE.md` placeholders ([`references/identity.md`](references/identity.md)) |
| `/inspire-config theme` | product | define or update the design-system default ([`references/theme-interview.md`](references/theme-interview.md)) |
| `/inspire-config stack` | technical | the target, then a shipped seed or the layer-by-layer interview, and the product roots ([`references/seeds.md`](references/seeds.md), [`references/stack-interview.md`](references/stack-interview.md)) |
| `/inspire-config emanate` | technical | derive, ask, validate, then write `.inspire/emanate.yml` on approval ([`references/derive.md`](references/derive.md)) |
| `/inspire-config review` | — | read-only: the foundation checklist ([`references/foundation-review.md`](references/foundation-review.md)), then, when `.inspire/emanate.yml` exists, its validation ([`references/validate.md`](references/validate.md)). Writes nothing |

With no argument, run `review` and offer `init`.

## References

Read the reference before the step it covers. The table is an index, not the flow.

| Reference | What it holds |
|---|---|
| [`wizard.md`](references/wizard.md) | The `init` flow: the order of the questions, which are product and which technical, and how a default is kept |
| [`spec-config.md`](references/spec-config.md) | `.inspire/config.json`: its keys, who reads them, the checks, and changing the language |
| [`seeds.md`](references/seeds.md) | The targets, and the seed each one gets: profiles, image and layout |
| [`stack-interview.md`](references/stack-interview.md) | The `stack` flow: shape, layers, datastores, stack skills, wire conventions, test infrastructure, worktree recipe, quality gates |
| [`theme-interview.md`](references/theme-interview.md) | The `theme` flow, including abstracting a theme from a mockup's CSS |
| [`identity.md`](references/identity.md) | The `identity` flow: `CLAUDE.md` placeholders and the root `README.md` |
| [`foundation-review.md`](references/foundation-review.md) | The read-only checklist over the spec config and the bootstrap layer |
| [`format.md`](references/format.md) | `emanate.yml`: every key, its rule and the factory's exact error; how the factory runs each key; the quoting rule; a worked example |
| [`derive.md`](references/derive.md) | The `emanate` flow: from `stack.md`, the seed and the stack skills to each key, the questions, what is never deduced, an empty project, updating an existing file |
| [`validate.md`](references/validate.md) | The factory's reader, the checks it cannot make, the optional image probe, and the hand-over |

## Asking

Every question this skill asks follows these four rules, in every flow.

1. **Mark each question** `[product]` or `[technical]`, as its reference marks it.
2. **Show the current value** — the shipped default, or what the project already
   set — and offer to keep it. Never assume the operator wants the default, and never
   make them retype it.
3. **A technical question offers "I don't know — keep the default"** as an answer.
   Taking it writes nothing for that question, and the closing report lists the
   question under *left at the default, for a technical operator*.
4. **Never ask what a file already answers.** A value in `.inspire/config.json`,
   `stack.md` or a compose file is read, shown and confirmed, never asked afresh.

## The `emanate` flow

1. **Preconditions.** A git repository; `<kb_root>/00_bootstrap/stack.md` exists;
   the stack skills resolve. `ios` in `profiles` stops the flow: iOS needs macOS and
   the factory's sandbox is Linux.
2. **Read** `.inspire/config.json`, `stack.md`, every `*.face.md` and `*.bundle.md`
   under `<kb_root>/01_spec/` (their `package` and `profiles`), and the resolved
   stack skills.
3. **Inspect** the repository, read-only: lockfiles, `package.json` scripts, runner
   configs, test directories, the compose file, `.gitignore`, and
   `.inspire/emanate.json` when it exists.
4. **Propose** the whole draft before the first question. Each key carries one
   line saying where it came from: *derived from X*, *from the seed*, or *proposed,
   confirm*.
5. **Ask** only what cannot be deduced, one question at a time, the default in
   brackets. "I don't know" is accepted and recorded as undecided.
6. **Validate** the draft with the factory's reader, then with the checks it
   cannot make. One error per round, since the reader stops at the first.
7. **Write** on approval, then tell the operator what to commit and on which
   branch. On an existing file the flow proposes a migration, never a rewrite
   ([`references/derive.md`](references/derive.md) § Updating an existing file). An
   `.inspire/emanate.json` is moved under `factory` and deleted
   ([`references/derive.md`](references/derive.md) § Migrating `emanate.json`).

## Rules

> **Output language.** Talk to the operator in the project's declared
> `output_language` (default English), and write `stack.md`, `theme.md`,
> `project.md` and the README in it, per
> [`_references/output-language.md`](../_references/output-language.md).
> `emanate.yml` is machine-read: keys, `image.description`, phase and check names
> stay in English, since the factory quotes them inside English prompts.

> **Writing contract.** `project.md`, `stack.md`, `theme.md`, `glossary.md`,
> `style-tokens.md`, the project README and operator-facing prose follow
> [`_references/writing-style.md`](../_references/writing-style.md). `glossary.md` is
> R4's term list and `style-tokens.md` is R6's and R7's token list. This skill owns
> writes to both: a glossary row lands when an interview settles a naming question,
> carrying the operator's own word.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **`review` is read-only.** Every other subcommand presents a plan or a diff before
   it writes.
2. **Configuration is upstream of everything.** A change here can ripple to specs,
   screens, the prototype and production code. Surface the propagation; never edit
   those layers silently.
3. **Load-bearing choices are ADRs.** Replacing a framework or the primary color, or
   changing the shape, is recorded as a global ADR (`/inspire-adr`), kept in sync
   with `stack.md` and `theme.md`.
4. **`project.md` and `stack.md` are endorsed-only.** An interview generates them, so
   writes to them carry no `produced` stamp; on an explicit operator yes they may be
   endorsed via `.inspire/bin/trust.sh endorse <file>`
   ([trust-stamps](../_references/trust-stamps.md#scope)).
5. **Gates ship with the stack.** `stack` installs the in-repo quality gates from the
   resolved stack skills and records the project's answers under `stack.md`'s
   `## Quality gates`; the server-side half becomes a tracker ticket with a human
   owner, never reported as done
   ([`_references/quality-gates.md`](../_references/quality-gates.md)).
6. **Never claim a validation that did not run.** Without the factory's reader,
   the verdict is *validation pending*, said in those words.
7. **Write only what the reader accepts today.** A key the factory does not yet
   read fails the whole run, so a key the operator remembers from a ticket
   (`tests`, `roots`, `report`) is never written until validation accepts it.
   A `review` check needs a factory with review checks (0.11.0 or later); an
   older reader refuses it, so validate before proposing one. The `factory` section
   needs a factory 0.13.0 or later: an older reader refuses it as an unknown key.
   `spec_strictness`, `spec_max_revisions` and `spec_classifier_model` need a
   factory 0.18.0 or later, for the same reason, and `check_concurrency` 0.19.0 or later.
   The parallel e2e flags also wait for 0.19.0: an older factory caps each unit's CPUs,
   so the rule proposes them only on 0.19.0 or later. The version is `version` in
   `$INSPIRE_FACTORY_ROOT/orchestrator/package.json`, the checkout validation uses
   ([`validate.md`](references/validate.md)). With no checkout the version is unknown:
   propose neither, and say why.
   `run_related` is the exception: it is written by default, with no check of the
   factory's version. A factory that does not know it refuses the file when the run
   starts, before any unit, with `… has unknown key run_related`; the fix is to
   update the factory, not to drop the key.
8. **Never write a secret.** `env` is committed, and every agent reads it in
   plain text. Test credentials only.
9. **Never invent an image.** An image is pulled at every run; a reference that
   cannot be pulled stops it. A seed names its image
   ([`seeds.md`](references/seeds.md)), so a project on a seed gets that one and no
   image question. Any other project gets a proposal the operator confirms.
10. **Never start a service** and never leave a container behind. The optional
    image probe in [validate.md](references/validate.md) runs one throwaway container on an explicit yes.
11. **The operator commits.** A run reads `.inspire/emanate.yml` from its clone of
    `factory.base_branch`, so only the committed file counts: an uncommitted edit never
    reaches it. Only `base_branch` itself is read from the working tree, because the
    factory needs it before it clones. Say so every time the file is written, offer
    the commit command, and never run it unasked. `.inspire/config.json` is committed
    the same way.
12. **No silent overwrite.** An existing file is changed through a shown diff and
    an approval, block by block or change by change.
13. **Consult the task tracker** (`/inspire-task list`) for tracked configuration
    work.

## Related skills

- `/inspire-screens design-system` — owns the live design system the theme seeds.
- `/inspire-face` — declares each face and bundle the shape interview names, with its
  `package` and `profiles`.
- `/inspire-prototype` — builds the horizontal prototype on this stack and theme.
- `/inspire-adr create` — records load-bearing stack and theme decisions.
- the stack skills — their `## Build & verify` and `## Test conventions`.
