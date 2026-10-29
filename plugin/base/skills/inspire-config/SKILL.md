---
name: inspire-config
description: "Write and check the project's .inspire/emanate.yml, the file that tells INSPIRE Factory which image, services, environment, setup and checks every unit runs with: derive a proposal from stack.md and its profiles, ask what they cannot answer, and validate it with the factory's own reader. Use when preparing a project for its first factory run, after a stack change, or when the factory refuses the file. Operator work only: never part of coding a unit."
argument-hint: "init|review"
user-invocable: true
---

# /inspire-config — The factory's project file

## Scope

**INSPIRE Factory** is the separate service that runs emanation for a project in
containers. It reads one file from the project, `.inspire/emanate.yml`, and stops
the run without it. This skill owns that file: it explains the format, proposes the
file from what the knowledge base already declares, asks for what it cannot
deduce, and validates the result.

**Owns:** `.inspire/emanate.yml`.

**Does NOT own:**

- `.inspire/emanate.json` — the factory's own settings (`model`, `review_model`,
  `sandbox`, `base_branch`, `max_tries`). Read for `base_branch`, never written.
- The skills and files a `review` check names. The check points at them; it never
  writes them.
- `stack.md` and the profiles. They are the source this skill derives from; a gap
  in them goes to `/inspire-bootstrap stack`, never patched here.
- Starting services, or any container left running.
- The commit. The operator commits the file; the skill says where.

## Invocation

- `/inspire-config init` — derive, ask, validate, then write the file on
  approval. On an existing file it proposes a migration, never a rewrite
  ([`references/derive.md`](references/derive.md) § Updating an existing file).
- `/inspire-config review` — read-only: validate the committed file and
  list every warning from [`references/validate.md`](references/validate.md).
  Writes nothing.

## References

Read the reference before the step it covers. The table is an index, not the flow.

| Reference | What it holds |
|---|---|
| [`format.md`](references/format.md) | Every key, its rule and the factory's exact error; how the factory runs each key; the quoting rule; a worked example |
| [`derive.md`](references/derive.md) | The `init` flow: from `stack.md` and the profiles to each key, the questions, what is never deduced, an empty project, updating an existing file |
| [`validate.md`](references/validate.md) | The factory's reader, the checks it cannot make, the optional image probe, and where the file must be committed |

## The flow

1. **Preconditions.** A git repository; `<kb_root>/00_bootstrap/stack.md` exists;
   the profiles resolve. `ios` in `profiles` stops the skill: iOS needs macOS and
   the factory's sandbox is Linux.
2. **Read** `stack.md`, `surfaces.md` when present, and the resolved profiles.
3. **Inspect** the repository, read-only: lockfiles, `package.json` scripts, runner
   configs, test directories, the compose file, `.gitignore`.
4. **Propose** the whole draft before the first question. Each key carries one
   line saying where it came from: *derived from X*, or *proposed, confirm*.
5. **Ask** only what cannot be deduced, one question at a time, the default in
   brackets. "I don't know" is accepted and recorded as undecided.
6. **Validate** the draft with the factory's reader, then with the checks it
   cannot make. One error per round, since the reader stops at the first.
7. **Write** on approval, then tell the operator what to commit and on which
   branch.

## Rules

> **Output language.** Talk to the operator in the project's declared
> `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). The
> file itself is machine-read: keys, `image.description`, phase and check names
> stay in English, since the factory quotes them inside English prompts.

> **Writing contract.** Operator-facing prose follows
> [`_references/writing-style.md`](../_references/writing-style.md).

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **Never claim a validation that did not run.** Without the factory's reader,
   the verdict is *validation pending*, said in those words.
2. **Write only what the reader accepts today.** A key the factory does not yet
   read fails the whole run, so a key the operator remembers from a ticket
   (`tests`, `roots`, `report`) is never written until validation accepts it.
   A `review` check needs a factory with review checks (emanate-2); an older
   reader refuses it, so validate before proposing one.
3. **Never write a secret.** `env` is committed, and every agent reads it in
   plain text. Test credentials only.
4. **Never invent an image.** An image is pulled at every run; a reference that
   cannot be pulled stops it. Propose, then have the operator confirm.
5. **Never start a service** and never leave a container behind. The optional
   image probe in `validate.md` runs one throwaway container on an explicit yes.
6. **The operator commits.** The factory reads the committed file on the base
   branch, never the working tree; say so every time the file is written.
7. **No silent overwrite.** An existing file is changed through a shown diff and
   an approval, block by block or change by change.

## Related skills

- `/inspire-bootstrap stack` — owns `stack.md`, the source this skill reads.
- the stack skills — their `## Build & verify` and `## Test conventions`.
