---
name: inspire-code-nestjs
description: "NestJS stack conventions: layering, tests, forbidden patterns, quality gates, build commands and seed conventions. Use when writing or testing code in a NestJS package."
stack: nestjs
layer: backend
language: typescript

# The machine-checkable half of [references/quality-gates.md](references/quality-gates.md), verified by
# `.inspire/bin/profile-gates-installed.sh`. The prose says WHY; this says WHAT MUST BE
# TRUE, and the two are separate on purpose: the prose deliberately names rules this stack
# **rejects** (`complexity`), so a validator scraping it would demand the very thing the
# reasoning refuses.
#
# `literal` is grepped verbatim — no globbing, no regex — against `config`, resolved
# relative to the project's source root. `expect: absent` inverts it, which is how a
# deliberate non-adoption stays deliberate instead of drifting back in unnoticed.
gates:
  # Type-aware linting is a gate in its own right, not plumbing: without it oxlint skips
  # every `typescript/no-unsafe-*` rule below and they silently pass on everything.
  - literal: typeAware
    config: .oxlintrc.json
  - literal: typescript/no-explicit-any
    config: .oxlintrc.json
  - literal: typescript/no-non-null-assertion
    config: .oxlintrc.json
  - literal: typescript/no-unsafe-argument
    config: .oxlintrc.json
  - literal: typescript/no-unsafe-assignment
    config: .oxlintrc.json
  - literal: typescript/no-unsafe-call
    config: .oxlintrc.json
  - literal: typescript/no-unsafe-member-access
    config: .oxlintrc.json
  - literal: typescript/no-unsafe-return
    config: .oxlintrc.json
  - literal: typescript/ban-ts-comment
    config: .oxlintrc.json
  - literal: max-depth
    config: .oxlintrc.json
  - literal: max-lines-per-function
    config: .oxlintrc.json
  - literal: import/no-cycle
    config: .oxlintrc.json
  # The layer boundary: one `no-restricted-imports` override per layer.
  - literal: no-restricted-imports
    config: .oxlintrc.json
  - literal: vitest/expect-expect
    config: .oxlintrc.json
  - literal: vitest/no-disabled-tests
    config: .oxlintrc.json
  - literal: vitest/no-focused-tests
    config: .oxlintrc.json
  - literal: vitest/no-conditional-expect
    config: .oxlintrc.json
  # Off unless named: oxlint reports a stale suppression only when this option is set.
  - literal: reportUnusedDisableDirectives
    config: .oxlintrc.json
  # The local escape-hatch plugin: `references/oxlint-escape-hatches.mjs` in inspire-code-typescript.
  - literal: escape-hatches/require-reason
    config: .oxlintrc.json
  - literal: escape-hatches/no-restricted-disable
    config: .oxlintrc.json
  - literal: escape-hatches/no-double-cast
    config: .oxlintrc.json
  - literal: thresholds
    config: vitest.config.ts
  # Rejected on measured evidence — see [references/quality-gates.md](references/quality-gates.md). Re-adopting it is a decision,
  # so it must come with an edit here rather than arrive quietly. oxlint accepts the rule
  # under both names, so both are refused.
  - literal: '"complexity"'
    config: .oxlintrc.json
    expect: absent
  - literal: '"eslint/complexity"'
    config: .oxlintrc.json
    expect: absent
---

Rules here use MUST, MUST NOT, SHOULD and MAY (RFC 2119). MUST and MUST NOT are
required: code that breaks one is wrong. SHOULD is the default; depart from it only
with the reason written in the code or the commit. MAY is optional. A **Seed**
section is the project's own convention: code MUST follow it exactly as written
until the project edits it.

## Layering
Domain-driven, four layers. **domain/** — pure TypeScript interfaces, types, enums;
no framework imports. **infrastructure/** — persistence entities, repositories
(data access + a `toDomain()` mapper), and adapters for external systems; HTTP calls
to other services are wrapped in a repository too. **application/** — services hold
the business logic; one primary service per aggregate, dedicated services for
complex flows (no God objects). **controllers/** — DTOs (request DTOs implement the
domain interface; response DTOs map in their constructor) + the controller. Business
logic never lives in a controller.

- Business logic MUST live in `application/` services and MUST NOT live in a controller.
- A controller handler MUST call one service method and map its result; it MUST NOT
  catch, inspect or translate errors. Domain errors MUST reach HTTP through an
  exception filter (`@Catch(SomeDomainError)`), registered on the controller or the app.
- Request DTOs MUST implement the domain interface they carry; response DTOs MUST
  build themselves from the domain object in their constructor.

**Module boundaries.** A module exposes its application services and nothing below
them: another module never imports its `infrastructure/` or `domain/` internals — it
calls the exported service. Generic knowledge about an external system (the database
client, its value rendering, its driver-failure classification) is cross-cutting by
nature and goes to `src/common/<system>/` as a dedicated module exporting only the
client, **at first use** — parking it inside the first feature module that needed it
forces the second consumer to choose between duplicating it and violating the
boundary. The test of what belongs there: if the file's name carries the system's
name and not an entity's, it is shared. Connection configuration carries no entity
knowledge — a table or collection name belongs to the repository of the module that
owns the entity, never to the shared client's config.

- A module's `exports` MUST list only its `application/` services; it MUST NOT export a
  repository, an entity or anything else below them.
- The database client MUST live in `src/common/<system>/` (for example
  `src/common/database/`) from its first use, and its configuration MUST NOT import
  or name any feature module's entity, table or migration.

## Test conventions
- **Test data MUST come from Object Mothers.** Every spec, unit or e2e, MUST build entity
  data with that entity's mother (`new RecordMother().make({ projectId })`) and MUST NOT
  hand-write an entity object literal or a `buildX()`/`makeX()` helper. The unit that
  introduces an entity MUST write its mother in `test/support/mothers/`, extending the
  project's single abstract `Mother<T>` (written once, by the first such unit), with every
  field generated by `@faker-js/faker`; a test pins only the fields it asserts on. When
  faker is not yet a dependency, that unit MUST add it (`npm install -D @faker-js/faker`,
  committing the lockfile change): a `Math.random`/`node:crypto` stand-in is not a mother.
  Shape:
  [`references/testing.md`](references/testing.md) § Mothers.
- **Unit** (`*.spec.ts`) — **every application service MUST have one, and it is part
  of the feature's definition of done**: it covers the happy path and *every* business-logic
  branch and corner case the service owns. Exhaustiveness lives at this level because
  this level is cheap — dependencies are mocked (a typed auto-mock helper, not
  hand-rolled objects), so a case costs milliseconds — and each test asserts the
  returned value **and** each collaborator call. **Private methods are exercised
  through the public methods that use them**, never tested directly and never widened
  to `public` for a test: a test pinned to a private breaks on refactor, not on
  behavior, which is the definition of a fragile test.
- **E2E** (`*.e2e-spec.ts`) — **written first**, from the acceptance criteria: they
  describe what a caller observes, which is this level. Controllers and DB repositories
  against a **real database**; mock only what sits outside the boundary and assert what
  crossed it — the outbound HTTP request that was made (intercept and assert URL, method
  and body), and the full payload plus topic/key of every event published. E2E never
  overrides providers.
- **E2E means the assembled application.** A suite starts the app the way `main.ts`
  builds it — one exported app factory both share — and sends HTTP requests to it. A
  spec that constructs a service or controller by hand, with fakes for its ports, is a
  unit spec whatever its file is called, and never cites a `binding/*` claim.
- **Access goes through the real guard.** A test citing an `actor(…)` precondition or
  a `binding/guard` claim sends requests through the real authentication and role
  guard: the allowed actor, an actor without the role, and — when the precondition
  scopes access (a study, an organisation) — an actor holding the role in **another**
  scope. A test that grants the role in an unrelated scope and expects success asserts
  the hole, not the rule.
- **What a controller's e2e suite covers — and what it deliberately does not.** The
  derived contract list (criteria ∪ declared errors ∪ wire-convention cases ∪ ADR
  invariants), the happy path, and the corner cases that **change the caller-observable
  response**. Never every branch: each e2e case pays a real-database round trip and
  re-asserts every side effect (what persisted, the mocked third-party call, the mocked
  publish), so enumerating business-logic corner cases here inverts the test pyramid
  and buys a slow, expensive suite for coverage the service's unit spec already proved.
  A corner case that alters neither the response nor a boundary side effect belongs to
  the unit level. Every unit is born red→green.
- **Every DB repository has its own dedicated e2e suite** —
  `test/{module}/{entity}.repository.e2e-spec.ts`, exercising the repository class
  **directly** against the real store, never a mocked one: a mocked store tests the
  mock. Exhaustive by design: all its casuistics through its public methods —
  found/not-found, empty result, filters and pagination, the `toDomain()` mapping,
  constraint violations — asserting the full persisted document/row (built from the
  domain entity) as well as what a read returns. **The controller suite passing
  through the repository does not count as this coverage**: it proves the wiring, not
  the repository's contract. Nor does the pyramid economy above thin this suite out —
  that rule bounds the *controller* suite, where a branch has a cheaper home; a
  repository's casuistics have no cheaper home, because the store's real behavior *is*
  the contract. A repository without its own e2e spec is a missing test, same as a
  service without its unit spec.
- HTTP repositories (call an API, not a DB) are unit-tested — the contract is the
  parsing/mapping, not the transport.
- **Helpers and standalone logic** whose branches the e2e suite does not deliberately
  carry get their own colocated unit spec — nothing ships with untested branches merely
  because it is small.
- GIVEN/WHEN/THEN; use test-data builders so each test sets only the significant
  fields. Assert full response bodies and full persisted documents, built from the
  domain entity — never compared against the value under test. The fine-grained
  authoring rules — expect grouping, stub-groups, typed auto-mocks, matcher
  discipline, per-spec helpers — live in
  [`references/testing.md`](references/testing.md) and apply to every
  spec this profile governs.
- **Layout:** e2e files in `test/{module}/` mirroring the KB's modules, cross-cutting
  probes (readiness, API-doc contract) in `test/platform/`, shared harness in
  `test/support/`. Unit specs stay colocated with the unit (`src/**/*.spec.ts`).
- **The level roll-call.** Before the cycle closes,
  walk the diff; every row must hold, and a row that does not is **red, not debt**:

  | touched or created | required spec |
  |---|---|
  | application service | colocated `*.spec.ts` — every new branch and corner case covered |
  | controller / endpoint | its derived-list cases in `test/{module}/` |
  | DB repository | dedicated `test/{module}/{entity}.repository.e2e-spec.ts` |
  | HTTP repository | colocated unit spec (parsing/mapping) |
  | helper / pure logic | colocated unit spec, unless an e2e deliberately carries it — name which |
  | domain rule / invariant | unit spec on the domain unit (property-based where invariants fit) |

- **The two levels together are the change detector.** Held jointly, these conventions
  leave no unowned branch — coverage tends to 100% without anyone chasing the number —
  and, the actual point, a future functional change cannot land silently: a service
  behavior change surfaces in its unit spec, a contract change in the e2e suite, and
  both are re-entered through the same red→green TDD cycle as new code.
- Run: `npm run test` (unit) · `npm run test:e2e` (e2e). Both run on **Vitest**, unit
  specs under `vitest.config.ts` and e2e under `vitest.e2e.config.ts`.
- **Vitest MUST transform through SWC** (`unplugin-swc`, `swc.vite()` in both configs).
  Vitest's default transformer, esbuild, emits no `emitDecoratorMetadata`, and Nest's
  DI resolves constructor parameters from that metadata: without SWC an injected
  dependency arrives `undefined` and the failure looks like a broken provider, not a
  missing transform.
- **Each e2e FILE gets its own database, copied from one migrated template.** The
  e2e `globalSetup` applies the migrations once, with the project's own migration
  runner, to a template database, then closes every connection to it (Postgres refuses
  to copy a database anyone is connected to). Each file's `beforeAll` runs
  `CREATE DATABASE <file db> TEMPLATE <template db>`, which copies the migrated schema
  in milliseconds, and its `afterAll` runs `DROP DATABASE <file db> WITH (FORCE)` and
  awaits it. Derive the file's database name from its test path, never a shared
  constant, so a new file cannot forget. **The template's name is unique to the run:**
  the `globalSetup` names it with a random suffix
  (`` `e2e_template_${randomUUID().slice(0, 8)}` ``), hands the name to the files with
  Vitest's `project.provide` and `inject`, and its teardown drops only that template.
  The shards of one suite run different files but share the database server, and an
  INSPIRE Factory phase runs its checks at the same time: with one fixed template name,
  a shard drops or recreates the template another shard is copying from.
  **Never run the migrations per file:** each
  run starts the migration tool and replays every migration, which costs seconds per
  file and turns a suite of a few dozen files into minutes. A store without database
  templates keeps the same shape: build once, copy per file.
- **E2E files run one at a time in the config** (`fileParallelism: false` in the e2e
  Vitest config). The files share no tables, so this is a resource choice, not a
  correctness one, and the config keeps the choice that is safe everywhere: a developer's
  machine, and an INSPIRE Factory that caps each unit's CPUs. Running files side by side
  is the factory's e2e check's choice: `/inspire-config` adds `--fileParallelism` and a
  worker count to it when the Factory and the unit's memory allow, and four workers ran a
  genomics-suite e2e suite of 279 files in about 120 s, against 425 s one at a time. Never
  change the config to run files in parallel.

## Test infrastructure

**The probe recipe — run before the first red test.** The components come from `stack.md`'s
own `## Test infrastructure`; the compose file realizes them:

- Inspect: `docker compose config --services` — every declared component has a service.
- Status: `docker compose ps` — a service must be **healthy**, not merely `Up`. Compose
  services carrying a healthcheck report both, and `Up` is where a flaky e2e suite comes
  from: the container exists, the server is still opening its ports.
- **Never bring a component up from inside a run.** The operator may have it up on
  other ports or pointed at a shared instance, so who acts on an unhealthy component
  depends on whether anyone is there to act:
  - **attended** — ask the operator to run
    `docker compose up -d` (or `--wait`, which blocks until healthchecks pass), and
    wait for them.
  - **unattended** (an INSPIRE Factory run) — **refuse**, name the unhealthy components
    and print that command in the report. There is nobody to ask, and a unit agent that
    stops to ask spends the whole run waiting on a turn that never comes.
- Then run `npm run test:e2e` once. A connection error is **not** red; it is a suite that
  never ran — which is why an unattended run refuses instead of reading it as red and
  burning a unit's rework budget on it.

## Forbidden patterns
- Services MUST throw a **generic `Error` with `cause`** (or a domain error that passes
  `cause`) and MUST NOT throw HTTP exceptions — translating to HTTP is the exception
  filter's job.
- **Repositories MUST NOT validate input** — validation lives in the DTO (with a
  controller) or the service (without one).
- DI MUST use the concrete class when there is one implementation and an abstract class
  as the contract when there are several. It MUST NOT use interface + string token +
  `@Inject`.
- Class names MUST NOT carry an ORM/DB technology (`EmailTemplateRepository`, not
  `…MongooseRepository`).
- **No silent domain mutations** — every meaningful create/update/delete MUST emit the
  project's typed audit event from the service layer (never the controller or
  repository); operational logging is not a substitute. Scope and shape:
  [`references/coding-standards.md`](references/coding-standards.md).

## Review focus
- **api-contract**: the API MUST be documented with Swagger (`@nestjs/swagger`). Every
  route MUST carry `@ApiOperation` and `@ApiResponse`, every request and response DTO
  field MUST carry `@ApiProperty`, and the app MUST serve the OpenAPI document at
  `/api/docs` (add `@nestjs/swagger` with the first endpoint if the project lacks it).
  Request DTOs MUST validate at the boundary (`class-validator`), and the documented
  shape MUST match the actual one.
- **security**: new endpoints, guards and auth logic MUST pass OWASP checks —
  authorization (not only authentication), input validation, no sensitive data in
  logs or error responses.

## Quality gates

Read [references/quality-gates.md](references/quality-gates.md) before creating or
changing `.oxlintrc.json` or the coverage thresholds in `vitest.config.ts`, before
writing a disable directive or a cast a lint rule refuses, and before adopting or
dropping a lint rule.

## Build & verify
build: `npm run build` · lint: `npm run lint` (`oxlint`) · format: `npx oxfmt --check` ·
types: `npx tsgo --noEmit` · tests: `npm run test` + `npm run test:e2e` (`vitest run`)

The default toolchain is **oxlint** with `oxlint-tsgolint` for the type-aware rules,
**oxfmt** for formatting, **tsgo** (`@typescript/native-preview`) for type checking and
**Vitest** with `unplugin-swc` for tests. A project whose `stack.md` names other tools
uses its own commands, and declares its own `gates:` for them.

**Monorepo scoping.** In a workspace, scope every command to the target bundle's
package (its `package` field): `pnpm --filter {package} build|lint|test` (or the workspace tool's
equivalent — `npm -w {package} …`, `turbo run test --filter={package}`, `nx test
{package}`). Never run a workspace-wide install or build from a subcommand when a
filtered form exists. E2E still runs against a real database — filter which package's
suite runs, never what it runs against.

## Bindings

> **Seed.** The project's API convention: code MUST follow it exactly as written. The
> project MAY edit it to match its real API shape; the machinery reads whatever this
> section declares. See [`stack-skills.md`](../_references/stack-skills.md) § Seeds.

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
[`keyed-heads.md`](../_references/keyed-heads.md)) renders as that route's role
guard — `@UseGuards(AuthGuard, RolesGuard)` + `@Roles('{role}')`. No `actor(…)`
precondition → no guard and a public route. The guard is derived, so changing the
precondition changes the guard, and the two can never disagree.

**The safety net for that rule is `PR-25`**, since the rule is silent in both
directions: a precondition that states its access rule in *prose* renders no
guard either, and derives only a test-oracle claim about the prose, so nothing
asserts the denial. INSPIRE Factory's planner warns when a headless precondition
or error reads like an access rule.

Three claims derive from this section per action, with no authoring: the route
exists (`{action}/binding/route`) · it dispatches to that action's service method
(`{action}/binding/dispatch`) · its guard matches the actor constraint
(`{action}/binding/guard`). Their payloads are
[`derived-contract.md`](../_references/derived-contract.md) § Binding claims;
editing this section moves every action's binding fingerprints.

## Persistence

> **Seed**, as above — an ORM choice most of all. A project on another ORM replaces
> this section wholesale.

- **ORM:** TypeORM against the seeded Postgres stack.
- **Entity → table.** One table per domain entity, named with the same plural the
  binding path uses (`auth::user` → `users`), snake_case. The module is not part of
  the table name — it is the schema where the project uses schemas, and nothing
  otherwise.
- **Embedded entity → one column of its parent's table.** An entity with
  `embedded_in:` gets no table: its rows are one `jsonb` column on the parent's table,
  named with the embedded entity's plural (`findings::finding_call` →
  `finding_calls`), holding an array of objects keyed by its field names, `[]` by
  default. Its unit adds that column in its own migration and never touches the
  parent's other columns. Each element carries its own `id`, generated when it is
  appended; `nonnull`, `default(v)`, `enum`, `min`, `max`, `len` and `pattern` hold
  per element, enforced where the array is written, since no column `CHECK` below
  reaches an element of the array. An entity that already has a table of its own keeps it: the migration
  adds the column and copies and drops nothing, since code built earlier still reads
  and writes that table. Moving that code to the parent's row is a separate change.
- **Field → column.** snake_case; the column type comes from the language profile's
  *Rendering* table ([`inspire-code-typescript`](../inspire-code-typescript/SKILL.md)), never from a guess here.
  The field's `Constraints:` line renders as column constraints — `unique` → a unique
  index, `nonnull` → `NOT NULL`, `default(v)` → the expansion in that profile's
  *Mapping tokens*, and the words below.
- **`immutable` → a `BEFORE UPDATE` trigger** in the same migration that creates the
  column, raising when the column's value changes:
  `IF NEW.<col> IS DISTINCT FROM OLD.<col> THEN RAISE EXCEPTION …`. One trigger
  function per table covers every immutable column on it. The trigger is what makes
  `immutable` a **store** claim rather than a test one
  ([`keyed-heads.md`](../_references/keyed-heads.md) § Oracles): a
  repository convention is invisible to raw SQL and to the next repository, and
  TypeORM's own `update: false` only silences the write it builds — Postgres still
  runs anyone else's `UPDATE`.
- **`enum`, `min`, `max`, `len` and `pattern` → one `CHECK` per claim**, in the same
  migration that creates the column, named `<table>_<col>_<word>` so a violation names
  the claim it breaks:

  | word | `CHECK` |
  |---|---|
  | `enum(a\|b\|…)` | `CHECK (<col> IN ('a', 'b', …))` |
  | `min(n)` | `CHECK (<col> >= n)`; on a string type, `CHECK (char_length(<col>) >= n)` |
  | `max(n)` | `CHECK (<col> <= n)`; on a string type, `CHECK (char_length(<col>) <= n)` |
  | `len(n,m)` | `CHECK (char_length(<col>) BETWEEN n AND m)` |
  | `pattern(/…/)` | `CHECK (<col> ~ '…')`, the pattern between the slashes with each `'` doubled |

  A field with `min(1), max(100)` gets two `CHECK`s, never one `BETWEEN`: they are two
  claims, and each one's test expects its own constraint to fail. A null passes every
  `CHECK`, so a value is required only where the field also says `nonnull`. The checks
  are what make these words **store** claims
  ([`keyed-heads.md`](../_references/keyed-heads.md) § Oracles).
- **A pattern Postgres cannot read is refused.** `~` reads Postgres's own regular
  expressions, which differ from the JavaScript ones a validator runs. The unit's agent
  refuses a `pattern(/…/)` that holds any of these, and names the construct and the
  field:
  - `\b` and `\B`, which are a backspace in Postgres, not a word boundary;
  - a named group, `(?<name>…)`;
  - a Unicode property, `\p{…}` or `\P{…}`;
  - a flag after the closing slash.

  The fix is the pattern written without the construct, in the KB, or a form a project
  adds here for it.
- **The DTO keeps its validator.** Every rule a `CHECK` holds is also checked on the
  request DTO with `class-validator` (`@IsIn`, `@Min` and `@Max`, or `@MinLength` and
  `@MaxLength` on a string, `@Length`, `@Matches`), so
  a caller gets the validation status of the wire convention with the field named, never
  the `500` of a constraint violation. The `CHECK` is what holds the rule; the
  validator is what explains it to the caller. The field's claim is cited only by a
  test that writes past the DTO, in the repository's e2e suite, and expects Postgres to
  reject the row; a test of the validator covers an input's claim, never a field's.
- **Keys and stamps.** `id UUID DEFAULT gen_random_uuid()` is the primary-key
  convention. A stamp is a **column only when the entity declares the field** —
  this clause fixes the rendering (`created_at` / `updated_at` as `TIMESTAMPTZ`),
  never the presence. **No clause in this profile adds a column the contract does
  not carry**, which is the field→column rule the section already opens with: an
  entity that declares `created_at` and not `updated_at` withheld the second one,
  and a table given it anyway holds the insert time forever under a name that
  promises last-change.
- **The persistence entity is not the domain entity.** It lives in `infrastructure/`
  beside its repository and `toDomain()` mapper; the domain interface never imports
  the ORM (see `## Layering`).
- **Migrations live in `src/migrations/`,** one file per change, created with
  `npx typeorm migration:create src/migrations/<Name>`. It names the file
  `<ms>-<Name>.ts` and the class `<Name><ms>`, with `<ms>` from `Date.now()`; never
  number one by the previous migration plus one. TypeORM reads the instant from the
  class name's last 13 characters. Migrations are **append-shaped**: a new change
  is a new file, and a migration already merged is never edited.
- Never `synchronize: true` outside a throwaway local run — migrations are the only
  schema authority.

## Declaration-only tree

The recipe is the language profile's ([`inspire-code-typescript`](../inspire-code-typescript/SKILL.md) § Declaration-only
tree). One framework addendum: **decorators do not survive declaration emission**, so
routes, guards, DI tokens and `@ApiProperty` shapes are invisible in a packed tree.
Nothing is lost, but it is not all recovered from the same place: routes and guards
are derived from `## Bindings` above, which the test phase reads directly; the DI
shape (concrete class vs. abstract-class contract) follows from the domain/
infrastructure split in `## Layering` above, stated as a rule under
`## Forbidden patterns`; and `@ApiProperty` shapes are derived from the descriptor
plus the language profile's § Rendering.

## References

Deep material, read on demand — never load one whose topic the task does not touch:

- [`references/testing.md`](references/testing.md) — the spec-authoring
  conventions: GIVEN/WHEN/THEN grouping, stub-groups, typed auto-mocks, assertion
  discipline, per-spec helpers, the general rules. Read before writing or modifying
  any spec, mock, or assertion.
- [`references/db-assertions.md`](references/db-assertions.md) — worked
  e2e examples: read fixtures, domain→model/HTTP mappers, matcher helpers,
  `expectXInDb`, create/unchanged cases. Read when asserting persisted state.
- [`references/error-assertions.md`](references/error-assertions.md) —
  `toStrictEqual` with cause, custom exceptions, nested causes, anti-patterns. Read
  when asserting a throw or rejection.
- [`references/nock-helpers.md`](references/nock-helpers.md) — the
  static helper-class template for mocking external HTTP in e2e. Read when a test
  touches an external API.
- [`references/coding-standards.md`](references/coding-standards.md) —
  the audit-event rule in full, and typed invariants (`NonEmptyArray` + assertion
  functions). Read when writing a service mutation or a validated boundary.
- [`references/quality-gates.md`](references/quality-gates.md) — the lint,
  coverage and escape-hatch rules with their reasons. Read when creating or changing
  `.oxlintrc.json` or the coverage thresholds, or before suppressing a lint rule.
