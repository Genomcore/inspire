# ADR — A face declares its application state in one store

- **Status:** Proposed — 2026-11-13
- **Amends:** [adr-kb-structure](adr-kb-structure.md) **D5** (what a face holds): a face
  gains a store file beside its face file.
- **Scope:** The application state a face keeps between screens, who reads and writes it,
  and how the shell binds data. Not session renewal (a process that may refresh a store
  key, specified on its own), not a process writing the store.

---

## Context

Only a screen can bind data. A screen's `## Bindings` names the actions that feed it, and
the binding lives as long as the screen does. Two things a real application holds fall
outside that:

- **The shell shows data.** The sidebar of a Genomics Studio face shows the signed-in user
  and the study being worked on. The shell is a layout entry, and a layout holds
  measurements only, so the field report found a shell that could not say where its data
  came from. The Factory built a sidebar with neither.
- **State outlives a screen.** The study a person picked stays picked as they move between
  screens, and reloading the page keeps it. Nothing in the KB can say that, so each screen
  reloads what it needs and the choice is lost on every navigation, or the implementer
  invents a store the specification never mentions and no claim covers.

Both are the same gap: the face has state of its own, and the KB has no place to write it.

## Decisions

### D1 — A face holds one store

The store is `inspire_kb/01_spec/_faces/{face}/{face}.store.md`, beside the face file. A
face has at most one store, and a store belongs to exactly one face: a face is one
application, and two applications share no state. The store's id is its file name without
the typed extension, which is its face's id, and it carries no `id:` field. Its frontmatter
holds `lifecycle:`, the shared four-state enum.

A face with no state across screens has no store file. A store whose file name names no
face is an error.

### D2 — A server key is loaded by one action, on a declared trigger

`## STO2: Server keys` is a table: `Key` · `Action` · `Load` · `On error` · `Notes`. The
action is a link to its descriptor and is exposed to the face, like any action a screen
binds. `Load` has a closed vocabulary:

| Load | Means |
|---|---|
| `start-up` | loaded when the application starts, before the first screen renders |
| `first read` | loaded the first time a reader asks for it, then kept |
| ``on change of `k` `` | loaded again each time key `k` of this store changes; `k` is another key of this store |

A key loaded `on change of` a key passes that key's value to its action. A key holds the
action's output.

### D3 — A client key is declared with its starting value and how long it lasts

`## STO3: Client keys` is a table: `Key` · `Type` · `Initial` · `Persist` · `Notes`. `Type`
resolves like every other `Type` cell in the KB. `Initial` is the value before anything
writes the key, or `—` for empty. `Persist` has a closed vocabulary: `none` (lost on
reload), `session` (kept until the browser session or the app process ends), `local`
(kept across sessions on this device). How a profile renders each one is the stack
skill's.

Keys are unique across both tables.

### D4 — Failure has a default per class and an override per key

`## STO4: On error` is a table: `Class` · `Outcome`. A server key that fails to load takes
the outcome of its error's class. The classes are closed: `unauthenticated`, `forbidden`,
`not-found`, `unavailable`, and `other` for every error no row of its own matches. A key's
own `On error` cell, when it is not `—`, replaces the default for that key.

An outcome takes one of three forms: `→ [{screen-id}]({path})` (navigate), `keep` (the key
keeps its last value) and `clear` (the key becomes empty). A reader shows a failure as one
of its own states, anchored on its data key.

### D5 — A reader names the key in a data row

A screen reads a store key with a `### Data` row whose `Action` cell is ``store `k` ``
instead of an action link. The row keeps a screen-local key, so a state anchors on it
like on any other data key. The store read is the face's own store: a screen belongs to
one face, so the cell names no face.

### D6 — Writes are outcomes

A screen or the shell writes the store as the outcome of something it already declares:

- **A dispatch.** `On success` takes ``set store `k` `` (the key becomes the action's
  output) and ``refresh store `k` `` (server key `k` loads again through its own action).
- **A transition.** `### Navigation` gains an optional `Then` column:
  ``set store `k` from param `p` ``, where `p` is a parameter the target declares. A
  person picking a study sets the current study as they open it, with no action behind
  it.

An outcome cell holds one or more outcomes joined by `; `, at most one of them a navigate
or a `state`, so a dispatch can refresh a key and leave the screen. A cell with one
outcome reads as before, so no existing claim changes.

Only screens and the shell write the store. A process writing it is out of scope here.

### D7 — The shell binds data like a screen

A layout that is a face's shell carries `## LAY8: Bindings` with `### Data`,
`### Dispatches`, `### Navigation` and `### States`, in the screen's format, store forms
included. It has no `### Parameters`: no route opens the shell.

With one face, its shell is the layout entry `shell`, as before. With several faces, each
face's frontmatter names its own shell in `shell_layout:` (default `shell`), and that entry
lists the face in `faces:`. A shell entry that frames several faces cannot bind data,
because a binding resolves against one face's store and bundles.

### D8 — Claims

| Claim id | Payload |
|---|---|
| `{face}/store/{key}/load` | action id · load trigger |
| `{face}/store/{key}/initial` | type name · initial value |
| `{face}/store/{key}/persist` | persist value |
| `{face}/store/{key}/on-error` | the key's own outcome, when it declares one |
| `{face}/store/on-error/{class}` | the outcome |

A reader's and a writer's claims are the screen's or the shell's own binding claims: a
data row that reads ``store `k` `` is `{screen-id}/data/{key}` with `store:k` in place of
the action id, and a dispatch outcome or a navigation `Then` feeds its row's fingerprint.
A shell's binding claims are keyed by the layout id, `{layout-id}/data/{key}` and so on.

The store is a unit of its own kind, `store`, derived like the others. Every reader and
writer requires it, so the store is built before the screens and the shell that use it.

### D9 — The KB is stack-neutral; the stack skill renders the store

The store file names no library, no context, no hook. Each frontend stack skill carries a
`## Store` section that says how its stack renders a store, a load trigger, a persist
value and an outcome.

### D10 — Ownership

`/inspire-store` owns every `*.store.md`. `/inspire-screens` owns the reader and writer
forms in a screen and the shell's `## LAY8: Bindings`. `store-coherence.sh` checks a store
and every reference to one: the face exists, the keys are unique, the vocabularies hold,
each `on change of` names another key of the store and no chain of them loops, each
``store `k` `` names a declared key, a `refresh` names a server key, and a key no reader
reads is a warning. `face-exposure.sh` checks a store's actions against the face's
bundles, as it checks a screen's.

## Consequences

- The Factory derives a new kind, `store`, and a layout entry that is a face's shell
  carries binding claims. Both ship in the Factory release that reads this version.
- Session renewal (a token process) is specified on its own. When it needs the signed-in
  user to reload, the process will refresh a store key, and that ADR extends D6 to it.
- A KB with no store file is unchanged, and so is every claim in it.
