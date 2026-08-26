---
kind: inspire-code-profile
id: nestjs
layer: backend
language: typescript
---

## Layering
Domain-driven, four layers. **domain/** — pure TypeScript interfaces, types, enums;
no framework imports. **infrastructure/** — persistence entities, repositories
(data access + a `toDomain()` mapper), and adapters for external systems; HTTP calls
to other services are wrapped in a repository too. **application/** — services hold
the business logic; one primary service per aggregate, dedicated services for
complex flows (no God objects). **controllers/** — DTOs (request DTOs implement the
domain interface; response DTOs map in their constructor) + the controller. Business
logic never lives in a controller.

## Test conventions
- **Unit** (`*.spec.ts`) — services with their dependencies mocked (a typed
  auto-mock helper, not hand-rolled objects); assert the returned value **and** each
  collaborator call.
- **E2E** (`*.e2e-spec.ts`) — controllers and DB repositories against a **real
  database**; mock only outbound external HTTP (intercept and assert the request was
  made). E2E never overrides providers.
- HTTP repositories (call an API, not a DB) are unit-tested — the contract is the
  parsing/mapping, not the transport.
- GIVEN/WHEN/THEN; use test-data builders so each test sets only the significant
  fields. Assert full response bodies and full persisted documents, built from the
  domain entity — never compared against the value under test.
- Run: `npm run test` (unit) · `npm run test:e2e` (e2e).

## Forbidden patterns
- Services throw a **generic `Error` with `cause`**, never HTTP exceptions —
  translating to HTTP is the controller/filter's job.
- **Repositories never validate input** — validation lives in the DTO (with a
  controller) or the service (without one).
- DI by concrete class when there is one implementation; an abstract class as the
  contract when there are several. Never interface + string token + `@Inject`.
- No ORM/DB technology in class names (`EmailTemplateRepository`, not
  `…MongooseRepository`).

## Review focus
- **api-contract**: request/response DTOs validate at the boundary
  (`class-validator`) and the OpenAPI/Swagger surface (`@ApiProperty`,
  `@ApiOperation`, `@ApiResponse`) matches the actual shape.
- **security**: OWASP checks on new endpoints, guards, and auth logic —
  authorization (not only authentication), input validation, no sensitive data in
  logs or error responses.

## Build & verify
build: `npm run build` · lint: `npm run lint` · types: `npx tsc --noEmit` ·
tests: `npm run test` + `npm run test:e2e`

**Monorepo scoping.** In a workspace, scope every command to the target surface's
package: `pnpm --filter {package} build|lint|test` (or the workspace tool's
equivalent — `npm -w {package} …`, `turbo run test --filter={package}`, `nx test
{package}`). Never run a workspace-wide install or build from a subcommand when a
filtered form exists. E2E still runs against a real database — filter which package's
suite runs, never what it runs against.

## Bindings

> **Seed.** Everything below is a default this template ships, not a rule INSPIRE
> enforces. Edit it to match the project's real API shape; the machinery reads
> whatever this section declares. See [`README.md`](README.md) § Seeds.

An action's binding is **derived from its id**, never authored per action. An id is
`{module}::{entity}::{verb}`; the path is `/{module}/{entities}`, where `{entities}`
is the entity name pluralized (default `+s`, kebab-cased when multi-word) and
`{id}` is the entity's identifying input.

| verb | method + path |
|---|---|
| `create` | `POST /{module}/{entities}` |
| `list` | `GET /{module}/{entities}` |
| `get` | `GET /{module}/{entities}/{id}` |
| `update` | `PATCH /{module}/{entities}/{id}` |
| `delete` | `DELETE /{module}/{entities}/{id}` |

**Any other verb is a named operation**, never bent into one of the five. It takes
the entity's identifier as an input → `POST /{module}/{entities}/{id}/{verb}`; it
does not → `POST /{module}/{entities}/{verb}`. Always `POST` — a named operation
carries no idempotency promise, and a verb that genuinely has one is one of the five.
Multi-word verbs kebab-case (`reset_password` → `reset-password`). Irregular plurals
are declared as override rows in this section; the seed has none.

**Controller placement.** One controller per entity, `{module}/{entity}.controller.ts`,
carrying every route of that entity. The controller method calls the application
service method of the same name as the verb.

**The guard comes from the actor constraint.** A `P{n} — actor({role})` precondition
(vocabulary V3 of
[`keyed-heads.md`](../../_references/keyed-heads.md)) renders as that route's role
guard — `@UseGuards(AuthGuard, RolesGuard)` + `@Roles('{role}')`. No `actor(…)`
precondition → no guard and a public route. The guard is derived, so changing the
precondition changes the guard, and the two can never disagree.

Three claims derive from this section per action, with no authoring: the route
exists · it dispatches to that action's service method · its guard matches the
actor constraint.

## Persistence

> **Seed**, as above — an ORM choice most of all. A project on another ORM replaces
> this section wholesale.

- **ORM:** TypeORM against the seeded Postgres stack.
- **Entity → table.** One table per domain entity, named with the same plural the
  binding path uses (`auth::user` → `users`), snake_case. The module is not part of
  the table name — it is the schema where the project uses schemas, and nothing
  otherwise.
- **Field → column.** snake_case; the column type comes from the language profile's
  *Rendering* table ([`typescript.md`](typescript.md)), never from a guess here.
  The field's `Constraints:` line renders as column constraints — `unique` → a unique
  index, `nonnull` → `NOT NULL`, `default(v)` → the expansion in that profile's
  *Mapping tokens*. `immutable` has no column form: it is enforced in the repository
  and asserted by a test.
- **Keys and stamps.** `id UUID DEFAULT gen_random_uuid()` primary key;
  `created_at` / `updated_at` as `TIMESTAMPTZ`.
- **The persistence entity is not the domain entity.** It lives in `infrastructure/`
  beside its repository and `toDomain()` mapper; the domain interface never imports
  the ORM (see `## Layering`).
- **Migrations are append-shaped.** `src/migrations/`, one timestamp-named file per
  change. Re-emanating a changed entity **appends** a migration; an existing one is
  never edited, reordered or deleted — not even one that has only ever run locally.
  Generated once is generated forever; a mistake is corrected by the next migration.
- Never `synchronize: true` outside a throwaway local run — migrations are the only
  schema authority.

## Declaration-only tree

The recipe is the language profile's ([`typescript.md`](typescript.md) § Declaration-only
tree). One framework addendum: **decorators do not survive declaration emission**, so
routes, guards, DI tokens and `@ApiProperty` shapes are invisible in a packed tree.
Nothing is lost, but it is not all recovered from the same place: routes and guards
are derived from `## Bindings` above, which the test phase reads directly; the DI
shape (concrete class vs. abstract-class contract) follows from the domain/
infrastructure split in `## Layering` above, stated as a rule under
`## Forbidden patterns`; and `@ApiProperty` shapes are derived from the descriptor
plus the language profile's § Rendering.
