---
name: inspire-code-typescript
description: "TypeScript conventions: how semantic types render as types, schemas and columns, how mapping tokens expand, and the declaration-only tree. Use when writing or testing TypeScript code."
stack: typescript
layer: language
---

Rules here use MUST, MUST NOT, SHOULD and MAY (RFC 2119). MUST and MUST NOT are
required: code that breaks one is wrong. SHOULD is the default; depart from it only
with the reason written in the code or the commit. MAY is optional. A **Seed**
section is the project's own convention: code MUST follow it exactly as written
until the project edits it.

The **language profile** for TypeScript: the one home for how a semantic type
renders at the implementation boundary, and for how this language yields a
declaration-only tree. It carries no architecture — layering, tests, forbidden
patterns and build commands belong to the framework profiles that declare
`language: typescript` (see [`stack-skills.md`](../_references/stack-skills.md) § The composition axis).

The universal semantic vocabulary — what each type *means* and the predicate it
must satisfy — lives in
[`inspire-domain/references/type-mapping.md`](../inspire-domain/references/type-mapping.md)
and is stack-agnostic. This file renders it.

## Rendering

One row per universal semantic type. SQL is Postgres (see *Engine notes*).

| Semantic | TypeScript | OpenAPI 3 | SQL |
|---|---|---|---|
| `email` | `string` | `{type: string, format: email}` | `VARCHAR(255)` |
| `uuid` | `string` | `{type: string, format: uuid}` | `UUID` |
| `timestamp` | `string` | `{type: string, format: date-time}` | `TIMESTAMPTZ` |
| `date` | `string` | `{type: string, format: date}` | `DATE` |
| `password` | `string` | `{type: string, format: password}` | `TEXT` |
| `string` | `string` | `{type: string}` | `TEXT` |
| `integer` | `number` | `{type: integer}` | `INTEGER` |
| `number` | `number` | `{type: number, format: double}` | `DOUBLE PRECISION` |
| `boolean` | `boolean` | `{type: boolean}` | `BOOLEAN` |
| `json` | `Record<string, unknown>` | `{type: object}` | `JSONB` |
| `enum<A,B,C>` | `"A"\|"B"\|"C"` | `{type: string, enum: [A, B, C]}` | `TEXT CHECK (col IN (...))` |

`enum<…>` is parametric: the variants come from the descriptor, the shape from
this row.

## Mapping tokens

How each `Mapping`-column token expands here. The token *meanings* are universal
and defined in [type-mapping.md](../inspire-domain/references/type-mapping.md); only the expansions are this file's.

| Token | TypeScript | SQL default |
|---|---|---|
| `uuid()` | `crypto.randomUUID()` | `DEFAULT gen_random_uuid()` |
| `now()` | `new Date().toISOString()` | `DEFAULT NOW()` |
| `today()` | `new Date().toISOString().slice(0, 10)` | `DEFAULT CURRENT_DATE` |
| `current_user` | `ctx.user.id` | — (resolved in the app layer) |
| `input.{field}` | `input.{field}` | — (bound at runtime) |
| `hash({field})` | `await bcrypt.hash(input.{field}, 10)` | — (app layer) |
| `from {R.{field}}` | `(await read(R, {pk})).{field}` | — (app layer) |
| `matches {pattern}` | — (validator) | — |
| `—` | — | — |

## Project semantic types

A project declares its own semantic types in
`inspire_kb/00_bootstrap/semantic-types.md`,
and every one of them carries a **universal base type**.

- **No row here → render as the declared base type**, in all three targets. A
  project type is never a rendering hole; the base type is the guarantee that it
  always has one.
- **A row here wins.** To give a project type its own rendering, add a row to
  *Rendering* above (and to *Mapping tokens* if it introduces one), and point at
  this profile from that type's `Rendering` column in
  `00_bootstrap/semantic-types.md`. Adding project rows is the expected way to
  edit this file.
- A project type declaring **no** base type and having **no** row here has no
  rendering at all — an emanation-readiness refusal, not a silent `unknown`.

## Engine notes

The SQL column above is **Postgres**, the seeded default stack's database. On
another engine, edit the SQL column in place rather than adding a parallel one —
one project runs one engine, and two columns would let them disagree. The usual
substitutions: `UUID` → `CHAR(36)`, `TIMESTAMPTZ` → `DATETIME` /
`TIMESTAMP WITH TIME ZONE`, `JSONB` → `JSON`, `gen_random_uuid()` → the engine's
generator, `TEXT CHECK (…)` → a native `ENUM` where one exists.

## Compile stub

The form a declared-but-unimplemented method takes in this language. The contract
phase emits one per method and the implementer replaces it.

**A stub throws, and its message names every parameter:**

```ts
export function find(input: FindInput): Promise<Study> {
  throw new Error(`not implemented: find(${input.id})`)
}
```

Naming them is not decoration — it is what makes the stub legal. **The framework
profiles lint with oxlint, whose `no-unused-vars` (in its default `correctness`
category) reports a parameter a function never reads**, so a stub that ignores its
input is a lint finding. Reading it in the message is the escape that costs
nothing and holds under any configuration: oxlint's default lets an `_` prefix
through, but that renames the parameter the contract declared, and a project that
sets its own `argsIgnorePattern` takes the prefix away.

**And a stub is never a suppression.** An inline disable on a stub would ship a
suppression into code that is about to be filled in, and the next body would inherit
it — which is why the idiom is the *form of the stub* rather than a relaxation of
the gate.
Interpolate something the parameter carries (an id, a key); where it carries
nothing nameable, `String(param)` reads it.

## Escape-hatch plugin

[`references/oxlint-escape-hatches.mjs`](references/oxlint-escape-hatches.mjs) is an
oxlint JS plugin carrying the escape-hatch rules oxlint lacks
([`quality-gates.md`](../_references/quality-gates.md) Rule 4). A framework profile
that lints with oxlint gates its rules; the project copies the file into the package,
lists it in `.oxlintrc.json`'s `jsPlugins` and owns it from then on:

| rule | refuses |
|---|---|
| `escape-hatches/require-reason` | a disable directive that names no rule or gives no reason after `--` |
| `escape-hatches/no-restricted-disable` | a directive disabling a rule in its option list, under any plugin prefix, or one of the plugin's own rules |
| `escape-hatches/no-double-cast` | `as unknown as` |

oxlint's JS plugins are alpha and run without type information. A bare
`/* oxlint-disable */`, or an `oxlint-disable-line` naming the plugin's rules, switches
them off too; both stay visible in the diff.

## Declaration-only tree

How this language produces the bodies-stripped tree the test phase is packed
with — signatures and types present, implementations absent. TypeScript fuses
signature and body in one file, so the stripping is an emission, not a copy:

1. Type-check the target package with declaration emission only —
   `tsgo --declaration --emitDeclarationOnly --outDir <dest>` (per package, using
   the package's own `tsconfig`; a project that builds with another tool sets the
   equivalent flag rather than hand-editing sources). tsgo refuses an `outDir`
   with no `rootDir` when the sources sit below the `tsconfig`'s directory
   (`TS5011`); pass `--rootDir` set to the package root, which also keeps every
   emitted path matching its source.
2. The emitted `.d.ts` files replace the `.ts` sources in the packed tree, path
   for path. Nothing else moves: `package.json`, `tsconfig.json`, fixtures and
   the test directory are copied as they are.
3. **Emission is the gate.** A package that does not type-check emits nothing, so
   a declaration-only tree that cannot be produced is a defect in the contract
   phase's output — never a reason to pack the sources instead.

What survives: exported functions, classes and their public method signatures;
`interface`, `type`, `enum` and const declarations; generics; JSDoc, when
`"stripInternal"` is off. What does not: every function body, private members,
and **decorators** — so anything a framework encodes only in a decorator
(a NestJS route, a DI token) is invisible in the packed tree. That is why the
framework profiles declare their bindings as a convention rather than leaving
them to be read off the code: the convention is legible where the decorator is
not.
