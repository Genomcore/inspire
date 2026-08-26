# Semantic types

The **universal semantic vocabulary** used by action descriptors and entity documents: what each type means, the predicate a value of it must satisfy, and the meaning of every `Mapping`-column token. It is stack-agnostic and closed — a descriptor written against it stays portable across every language a project ever targets.

**Rendering lives elsewhere.** How `timestamp` becomes a TypeScript type, an OpenAPI fragment or a SQL column is a per-target question, and per-target answers live in the **language profile** (`inspire-code/profiles/{language}.md`, e.g. [`typescript.md`](../../inspire-code/profiles/typescript.md)). This file never carries a language, an engine or a schema dialect. The split has three homes:

| part | home |
|---|---|
| universal vocabulary + predicates | **this file** (runtime, stack-agnostic) |
| a project's own semantic types | [`00_bootstrap/semantic-types.md`](../../../../inspire_kb/00_bootstrap/semantic-types.md) (project content) |
| per-target rendering | the language profile ([`inspire-code/profiles/`](../../inspire-code/profiles/README.md)) |

## The vocabulary

| Semantic | Means | Predicate |
|----------|-------|-----------|
| `email` | A single addressable mailbox. | One `@`, a non-empty local part and a domain part. The exact pattern is a feature-level rule, not a type-level one. |
| `uuid` | An opaque unique identifier — never parsed, never ordered. | Canonical hyphenated 8-4-4-4-12 form. |
| `timestamp` | An instant on the timeline. | UTC, ISO-8601, second precision or finer. Stored and compared in UTC; a local rendering is a presentation concern. |
| `date` | A calendar day, with no time and no zone. | ISO-8601 `YYYY-MM-DD`. |
| `password` | A secret supplied by a human. | Never stored in plaintext, never logged, never read back — only written and verified. |
| `string` | Free text the platform enforces no structure on. | Any text; bounds and patterns come from the field's `Constraints:` line, not from the type. |
| `integer` | A whole number. | No fractional part. |
| `number` | A real number. | A fractional part is allowed. Exact decimal arithmetic (money) is a project semantic type, not this one. |
| `boolean` | Exactly two values. | `true` or `false` — never a third "unset" state; an absent value is nullability, which `Constraints:` declares. |
| `json` | A structured document the platform stores but does not interpret. | Any JSON value. A shape the platform *does* interpret is an entity, not a `json` field. |
| `enum<A,B,C>` | A closed value space, listed inline. | The value is literally one of the named members. Parametric — the members come from the descriptor. |

## Mapping-column tokens

The `Mapping` column of `## Entities` field tables uses small DSL tokens to say where a value comes from. Their **meanings** are universal and fixed here; their expansions are the language profile's. The agent expands them in surface manifests and in the descriptor's behavior section.

| Token | Means |
|-------|-------|
| `uuid()` | Generate a fresh identifier at write time. |
| `now()` | The current UTC instant at write time. |
| `today()` | The current calendar day at write time. |
| `current_user` | The session's authenticated user id. |
| `input.{field}` | A request input field, taken as supplied. |
| `hash({field})` | A one-way hash of the named input; the algorithm is the language profile's, never the descriptor's. |
| `from {R.{field}}` | A read of another entity's field (a foreign-key lookup). |
| `matches {pattern}` | Pattern validation, on reads only. |
| `—` | No mapping — a read column for keys, or a field supplied externally. |

## Extension rules

Which of the three homes a new type belongs in is decided by who would recognize it:

- **A new universal type** — one every project would recognize (`duration`, `url`) — is a **runtime change**: add a row above, PR-reviewed, with a brief rationale in the PR description, plus a rendering row in each shipped language profile.
- **A project's own type** (`money`, `tenant_id`, a domain identifier) goes in [`00_bootstrap/semantic-types.md`](../../../../inspire_kb/00_bootstrap/semantic-types.md), never here. Each one declares a **universal base type** from the table above, so it renders even where no language profile names it explicitly.
- **A rendering** — a new target language, a different SQL engine, a changed column type — is the **language profile's**, never this file's.

Two consequences worth stating:

- A project semantic type with neither a base type nor a rendering row is caught at emanation, not authoring time: `emanate plan` refuses a unit in that state as a readiness error (`profiles/README.md:76-77`), rather than emitting a guess.
- The `enum<...>` form is parametric. If the variants change between actions on the same entity, `entity-coherence` flags it as a field-conflict (different type-strings, even though the semantic kind matches).

## Type aliases (rejected)

These shorthand forms are **not** supported in the semantic DSL — use the canonical name in the table above:

| Rejected | Use instead |
|----------|-------------|
| `int` | `integer` |
| `bool` | `boolean` |
| `text` | `string` |
| `varchar(N)` | `string` (length is a downstream concern) |
| `numeric(p,s)` | `number` (precision is a downstream concern) |

Rejecting these keeps the descriptor portable: an engine-specific type expression belongs in a language profile, not in an authored descriptor.
