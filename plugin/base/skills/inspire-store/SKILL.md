---
name: inspire-store
description: "Lifecycle of a face's store — the application state a face keeps between screens (the signed-in user, the study being worked on, a cached list): create / update / review the {face}.store.md beside a face file. Use when a value must outlive one screen, survive a reload, or feed the shell (the sidebar, the top bar), or when a screen or the shell needs to read or write such a value."
---

# /inspire-store — The face's store

## Scope

A **store** is the state one face keeps across its screens: values loaded from the
server once and shared (the signed-in user, the list of studies) and values the
application itself holds (the study a person picked, a filter that survives a reload).
A screen binding lives as long as its screen; a store key lives as long as the face is
open, or longer when it persists.

One face, at most one store: `inspire_kb/01_spec/_faces/{face}/{face}.store.md`. Its
id is the face id, read from the file name; the file carries no `id:`. A face with no
state across screens has no store. Two faces never share one: a face is one
application.

This skill owns every `*.store.md` under `inspire_kb/01_spec/`. It does not own:

- the **readers and writers** — a screen's `### Data`, `### Dispatches` and
  `### Navigation` rows, and the shell layout's `## LAY8: Bindings`, are
  `inspire-screens`'. This skill offers those edits; it never applies them.
- the **actions** a server key loads through (`inspire-domain`), or the bundles that
  expose them to the face (`inspire-face`).
- **how a stack renders a store** — each frontend stack skill's `## Store` section.

## Invocation

- `/inspire-store create {face}` — the face's store file
- `/inspire-store update {face}` — add, change or retire a key, or an error default
- `/inspire-store review {face}` — the store and every reader and writer of it (read-only)

## Format

Template: [`templates/store.template.md`](templates/store.template.md). Frontmatter
holds `lifecycle:` (`draft` · `accepted` · `stable` · `superseded`) and nothing else.
The H1 is `# Store: {face display name}`.

| Section | What it holds |
|---|---|
| `## STO1: Purpose` | One paragraph: what the face keeps between screens and why no screen can hold it alone. |
| `## STO2: Server keys` | `Key` · `Action` · `Load` · `On error` · `Notes`. One row per value loaded from the server. |
| `## STO3: Client keys` | `Key` · `Type` · `Initial` · `Persist` · `Notes`. One row per value the application holds itself. |
| `## STO4: On error` | `Class` · `Outcome`. What a failed load does when its key declares nothing of its own. |

Drop `## STO2` or `## STO3` when the face has no key of that kind. Keys are unique
across both tables, and are the names readers and writers use.

### Server keys

- **`Action`** — a link to the action that loads the key. The key holds its output.
  The action must be exposed to the face by one of its bundles.
- **`Load`** — closed:

  | Load | Means |
  |---|---|
  | `start-up` | loaded when the application starts, before the first screen renders |
  | `first read` | loaded the first time a reader asks for it, then kept |
  | ``on change of `k` `` | loaded again each time key `k` of this store changes, with `k`'s value as its input |

  An `on change of` names another key of this store, and no chain of them loops.
- **`On error`** — `—` takes the default for the error's class from `## STO4`.
  Anything else replaces it for this key: `keep` (the key keeps its last value),
  `clear` (the key becomes empty) or `→ [{face}.{slug}]({path})` (navigate).

### Client keys

- **`Type`** — a semantic type, resolved like every `Type` cell in the KB.
- **`Initial`** — the value before anything writes the key, or `—` for empty.
- **`Persist`** — closed: `none` (lost on reload), `session` (kept until the browser
  session or the app process ends), `local` (kept across sessions on this device).

### On error

`Class` is closed: `unauthenticated`, `forbidden`, `not-found`, `unavailable`, and
`other` for every error no row of its own matches. Each class has at most one row.
`Outcome` takes the same three forms as a key's own `On error`.

A reader shows a failed key as one of its own states, anchored on its data key; the
store says what happens to the key, the screen says what the person sees.

### Readers and writers

Written in a screen or the shell, owned by `inspire-screens`
([format-screen.md](../inspire-screens/references/format-screen.md) § The store):

| Where | Form | Means |
|---|---|---|
| `### Data` → `Action` | ``store `k` `` | this binding reads key `k` |
| `### Dispatches` → `On success` | ``set store `k` `` | the key becomes the action's output |
| `### Dispatches` → `On success` | ``refresh store `k` `` | server key `k` loads again |
| `### Navigation` → `Then` | ``set store `k` from param `p` `` | client key `k` takes the value of parameter `p` of the target |

### Claims

| Claim id | Payload |
|---|---|
| `{face}/store/{key}/load` | action id · load trigger |
| `{face}/store/{key}/initial` | type name · initial value |
| `{face}/store/{key}/persist` | persist value |
| `{face}/store/{key}/on-error` | the key's own outcome, when it declares one |
| `{face}/store/on-error/{class}` | the outcome |

Reads and writes are claims of the screen or shell that declares them, never of the
store. The full contract is
[`_references/derived-contract.md`](../_references/derived-contract.md) § `store`.

## Subcommand: create

1. **Confirm it is store state.** Ask which screens need the value and how long it
   must live. A value one screen loads and drops is that screen's `### Data` row, not
   a store key: stop and say so.
2. **The face exists.** Its `{face}.face.md` must be on disk; a face with no file is
   an error, not an invitation to create one here. A store already present means
   `update`, not `create`.
3. **Interview the keys**, server keys first. For each one: its name, the action that
   loads it and when, or its type, starting value and persistence. Ask what the
   person should see when a load fails, class by class, and write the defaults.
4. **Every link has a file.** Links follow [kb-links.md](../_references/kb-links.md).
   An action that does not exist yet is created as a draft from
   [action.template.md](../inspire-domain/templates/action.template.md), in the same
   change. An action the face's bundles do not expose is named to the operator, with
   `/inspire-face` as the fix.
5. **Write the file** at `_faces/{face}/{face}.store.md`, from the template, with
   `lifecycle: draft`.
6. **Offer the readers and writers.** List the screens and the shell that read or
   write each key, with the row each one gains, and hand them to `/inspire-screens`.
   A key nothing reads is a finding at review.

## Subcommand: update

1. **Read the file and present the plan** — which keys change and why — before
   writing. The operator approves it.
2. **A key's name is what its readers cite.** Renaming one renames every
   ``store `k` ``, ``set store `k` ``, ``refresh store `k` `` and `on change of` that
   names it, in the same change, through `/inspire-screens` for screens and the shell.
3. **Retiring a key** removes its readers and writers first; a key still read is
   not retired.
4. **Every new link has a file**, as in `create`.

## Subcommand: review

Read-only. It reports, recommends and offers; it never edits.

1. **Run the validators:**

   ```bash
   .inspire/bin/store-coherence.sh {path}
   .inspire/bin/face-exposure.sh {path}
   ```

   `store-coherence` checks the store's tables and vocabularies, the `on change of`
   chains, and every reader and writer of the face. `face-exposure` checks that
   each server key's action is exposed to the face.
2. **Add the judgment the validators cannot make:**
   - **Is each key really shared?** A key one screen reads belongs in that screen.
   - **Is the load trigger right?** `start-up` delays the first screen; a key most
     sessions never read is `first read`.
   - **Is anything personal persisted `local`?** A device shared by two people keeps
     it. Say so when a key holds personal or clinical data.
   - **Does every failure land somewhere a person sees?** A `keep` on a key whose
     readers then show stale data with no hint is a gap worth a question.

Render findings in the shared operator-facing format from
[`_references/findings-format.md`](../_references/findings-format.md).

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Headings
> keep their section id (`## STO2: …`); machine-read tokens (frontmatter, keys,
> `Load`, `Persist`, `Class` and outcome values, link paths) stay verbatim.

> **Writing contract.** Store files follow
> [`_references/writing-style.md`](../_references/writing-style.md). `## STO1:
> Purpose` is normative prose (R1–R6). Referenced, never restated.

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **One store per face, and only that face reads it.** No key is shared across
   faces.
2. **The store is stack-neutral.** No library, hook, context or storage API is
   named in it: the stack skill renders it.
3. **A store changes only through its readers' outcomes.** Screens and the shell
   write it; nothing else does.
4. **`review` is read-only.** `update` requires the operator's approval of the plan
   before writing.
5. **Every link has a file.** A missing action is created as a draft from its
   template in the same change.
6. **Check and stamp every write.** After `create` or `update` writes the store
   file, run `.inspire/bin/review.sh <file>` and fix what it reports on that file:
   every error, and every warning the operator does not choose to keep
   ([write-checks](../_references/write-checks.md)). Then run
   `.inspire/bin/trust.sh stamp <file> --skill store`
   ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting one that
   carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).

## Related skills

- `/inspire-screens` — owns the readers and writers in screens, and the shell's
  `## LAY8: Bindings`.
- `/inspire-face` — owns the face the store belongs to and the bundles that expose
  its actions.
- `/inspire-domain` — owns the actions server keys load through.
- `/inspire-process` — a process does not write the store.
- `/inspire-workspace` — the global pre-PR review runs `store-coherence.sh` over the
  KB.
