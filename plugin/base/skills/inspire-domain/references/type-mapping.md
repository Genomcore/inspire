# Semantic type mapping

Single-source mapping from the semantic type DSL used in action descriptors to the shapes downstream consumers interpret: TypeScript, OpenAPI, SQL, and default-token expansions.

When an action descriptor declares a field with a semantic type (e.g. `email`, `uuid`, `timestamp`), the rows below define how that type lands at the implementation boundary — what the TypeScript surface expects, what the OpenAPI schema fragment looks like, what column type the SQL column ends up with, and how mapping-column tokens (e.g. `now()`, `uuid()`) resolve. The descriptor stays portable; the resolution happens at the implementation handoff.

## Mapping table

| Semantic | TypeScript | OpenAPI 3 | SQL | Default-token expansion |
|----------|------------|-----------|-----|-------------------------|
| `email` | `string` | `{type: string, format: email}` | `VARCHAR(255)` | — |
| `uuid` | `string` | `{type: string, format: uuid}` | `UUID` | `uuid()` → `gen_random_uuid()` (Postgres) |
| `timestamp` | `string` | `{type: string, format: date-time}` | `TIMESTAMPTZ` | `now()` → `NOW()` (Postgres) |
| `date` | `string` | `{type: string, format: date}` | `DATE` | `today()` → `CURRENT_DATE` |
| `password` | `string` | `{type: string, format: password}` | `TEXT` | — (never stored as plaintext) |
| `string` | `string` | `{type: string}` | `TEXT` | — |
| `integer` | `number` | `{type: integer}` | `INTEGER` | — |
| `number` | `number` | `{type: number, format: double}` | `DOUBLE PRECISION` | — |
| `boolean` | `boolean` | `{type: boolean}` | `BOOLEAN` | — |
| `json` | `Record<string, unknown>` | `{type: object}` | `JSONB` | — |
| `enum<A,B,C>` | `"A"\|"B"\|"C"` | `{type: string, enum: [A, B, C]}` | `TEXT CHECK (col IN (...))` | — |

## Mapping-column tokens

The `Mapping` column of `## Entities` field tables uses small DSL tokens to describe where a value comes from. The agent expands these in surface manifests and in the descriptor's behavior section:

| Token | Meaning | TypeScript | SQL default |
|-------|---------|------------|-------------|
| `uuid()` | Generate a new UUID at write time | `crypto.randomUUID()` | `DEFAULT gen_random_uuid()` |
| `now()` | Current UTC timestamp at write time | `new Date().toISOString()` | `DEFAULT NOW()` |
| `current_user` | The session's authenticated user id | `ctx.user.id` | — (resolved in app layer) |
| `input.{field}` | A request input field | `input.{field}` | — (bound at runtime) |
| `hash({field})` | bcrypt hash of the named input | `await bcrypt.hash(input.{field}, 10)` | — (app layer) |
| `from {R.{field}}` | A read of another entity's field (foreign key lookup) | `(await read(R, {pk})).{field}` | — (app layer) |
| `matches {pattern}` | Pattern validation (reads only) | — | — (validator) |
| `—` | No mapping (read column for keys, or the field is supplied externally) | — | — |

## Extension rules

- Unknown semantic types are flagged by `entity-coherence` as warnings (Touch=read field with a type the mapping table doesn't recognize). The agent surfaces the finding so the operator can either correct the type or extend this table.
- New semantic types are added by editing this file. PR-reviewed — additions should be accompanied by a brief rationale in the PR description.
- The `enum<...>` form is parametric. The mapping resolves to a TypeScript union and an OAS `enum`. If the enum's variants change between actions on the same entity, `entity-coherence` flags it as a field-conflict (different type-strings, even though the semantic kind matches).
- BSD vs Postgres SQL differences live here too, when they're worth calling out. The defaults above assume Postgres; other engines may need overrides documented as additional rows.

## Type aliases (rejected)

These shorthand forms are **not** supported in the semantic DSL — use the canonical name in the table above:

| Rejected | Use instead |
|----------|-------------|
| `int` | `integer` |
| `bool` | `boolean` |
| `text` | `string` |
| `varchar(N)` | `string` (length is a downstream concern) |
| `numeric(p,s)` | `number` (precision is a downstream concern) |

Rejecting these keeps the descriptor portable: SQL-engine-specific type expressions belong at the implementation boundary, not in the authored descriptor.
