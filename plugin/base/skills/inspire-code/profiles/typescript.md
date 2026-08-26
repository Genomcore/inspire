---
kind: inspire-code-profile
id: typescript
layer: language
---

The **language profile** for TypeScript: the one home for how a semantic type
renders at the implementation boundary, and for how this language yields a
declaration-only tree. It carries no architecture — layering, tests, forbidden
patterns and build commands belong to the framework profiles that declare
`language: typescript` (see [`README.md`](README.md) § The composition axis).

The universal semantic vocabulary — what each type *means* and the predicate it
must satisfy — lives in
[`inspire-domain/references/type-mapping.md`](../../inspire-domain/references/type-mapping.md)
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
and defined in `type-mapping.md`; only the expansions are this file's.

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
[`00_bootstrap/semantic-types.md`](../../../../inspire_kb/00_bootstrap/semantic-types.md),
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

## Declaration-only tree

How this language produces the bodies-stripped tree the test phase is packed
with — signatures and types present, implementations absent. TypeScript fuses
signature and body in one file, so the stripping is an emission, not a copy:

1. Type-check the target package with declaration emission only —
   `tsc --declaration --emitDeclarationOnly --outDir <dest>` (per package, using
   the package's own `tsconfig`; a project that builds with another tool sets the
   equivalent flag rather than hand-editing sources).
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
