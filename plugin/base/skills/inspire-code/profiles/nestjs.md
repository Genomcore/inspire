---
kind: inspire-code-profile
id: nestjs
layer: backend

# The machine-checkable half of `## Quality gates` below, verified by
# `.inspire/bin/profile-gates-installed.sh`. The prose says WHY; this says WHAT MUST BE
# TRUE, and the two are separate on purpose: the prose deliberately names rules this stack
# **rejects** (`complexity`), so a validator scraping it would demand the very thing the
# reasoning refuses.
#
# `literal` is grepped verbatim — no globbing, no regex — against `config`, resolved
# relative to the project's source root. `expect: absent` inverts it, which is how a
# deliberate non-adoption stays deliberate instead of drifting back in unnoticed.
gates:
  - literal: strictTypeChecked
    config: eslint.config.mjs
  - literal: ban-ts-comment
    config: eslint.config.mjs
  - literal: max-depth
    config: eslint.config.mjs
  - literal: max-lines-per-function
    config: eslint.config.mjs
  - literal: import-x/no-cycle
    config: eslint.config.mjs
  - literal: import-x/no-restricted-paths
    config: eslint.config.mjs
  # The resolver is a gate in its own right, not plumbing: without it the two rules above
  # resolve nothing and silently pass on everything.
  - literal: import-x/resolver-next
    config: eslint.config.mjs
  - literal: jest/expect-expect
    config: eslint.config.mjs
  - literal: jest/no-disabled-tests
    config: eslint.config.mjs
  - literal: jest/no-focused-tests
    config: eslint.config.mjs
  - literal: jest/no-conditional-expect
    config: eslint.config.mjs
  # Neither is in the plugin's `recommended` preset, so both must be enabled by name.
  - literal: eslint-comments/require-description
    config: eslint.config.mjs
  - literal: eslint-comments/no-unused-disable
    config: eslint.config.mjs
  - literal: coverageThreshold
    config: package.json
  # Rejected on measured evidence — see `## Quality gates`. Re-adopting it is a decision,
  # so it must come with an edit here rather than arrive quietly.
  - literal: "'complexity'"
    config: eslint.config.mjs
    expect: absent
  - literal: recommendedTypeChecked
    config: eslint.config.mjs
    expect: absent
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

## Test conventions
- **Unit** (`*.spec.ts`) — **every application service has one, and it is part of the
  feature's definition of done**: it covers the happy path and *every* business-logic
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
- **What a controller's e2e suite covers — and what it deliberately does not.** The
  derived contract list (criteria ∪ declared errors ∪ wire-convention cases ∪ ADR
  invariants), the happy path, and the corner cases that **change the caller-observable
  response**. Never every branch: each e2e case pays a real-database round trip and
  re-asserts every side effect (what persisted, the mocked third-party call, the mocked
  publish), so enumerating business-logic corner cases here inverts the test pyramid
  and buys a slow, expensive suite for coverage the service's unit spec already proved.
  A corner case that alters neither the response nor a boundary side effect belongs to
  the unit level — see `tdd.md` → Choosing the test level. Every unit is born red→green.
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
  [`nestjs/references/testing.md`](nestjs/references/testing.md) and apply to every
  spec this profile governs.
- **Layout:** e2e files in `test/{module}/` mirroring the KB's modules, cross-cutting
  probes (readiness, API-doc contract) in `test/platform/`, shared harness in
  `test/support/`. Unit specs stay colocated with the unit (`src/**/*.spec.ts`).
- **The level roll-call, concretely** (`tdd.md` → step 6). Before the cycle closes,
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
- Run: `npm run test` (unit) · `npm run test:e2e` (e2e).
- **E2E run serially, and that is a correctness requirement, not a performance choice.**
  `maxWorkers: 1` in the e2e jest config is load-bearing: the files share one real
  database, so concurrent runs interfere — and the interference surfaces as flakiness,
  not as an honest failure. Give each test FILE its own table/collection anyway (derive
  the name from the test path, never a shared constant, so a new file cannot forget),
  and make teardown synchronous where the store's drop is asynchronous by default — a
  drop that returns while the table is still detaching is a race the next run inherits.

## Forbidden patterns
- Services throw a **generic `Error` with `cause`**, never HTTP exceptions —
  translating to HTTP is the controller/filter's job.
- **Repositories never validate input** — validation lives in the DTO (with a
  controller) or the service (without one).
- DI by concrete class when there is one implementation; an abstract class as the
  contract when there are several. Never interface + string token + `@Inject`.
- No ORM/DB technology in class names (`EmailTemplateRepository`, not
  `…MongooseRepository`).
- **No silent domain mutations** — every meaningful create/update/delete emits the
  project's typed audit event from the service layer (never the controller or
  repository); operational logging is not a substitute. Scope and shape:
  [`nestjs/references/coding-standards.md`](nestjs/references/coding-standards.md).

## Review focus
- **api-contract**: request/response DTOs validate at the boundary
  (`class-validator`) and the OpenAPI/Swagger surface (`@ApiProperty`,
  `@ApiOperation`, `@ApiResponse`) matches the actual shape.
- **security**: OWASP checks on new endpoints, guards, and auth logic —
  authorization (not only authentication), input validation, no sensitive data in
  logs or error responses.

## Quality gates
**Absolute** (eslint — the agent hits these in its own loop and fixes them before
anything reaches the operator):
- `typescript-eslint` **`strictTypeChecked`**, not `recommendedTypeChecked` — it
  brings `no-non-null-assertion` and the stricter `any` rules with it.
- `max-depth` · `max-lines-per-function` · `max-lines`. Two caveats measured rather than
  assumed, both about the rule fitting the file kind: `max-lines-per-function` fires on
  every `describe` block, since a suite callback is a function to the linter — off for
  test files, with the reason written. `max-lines` fires on field-declaration files (a
  DTO with 300 property decorators is wide, not complex) — off for `dto/` and generated
  type modules, in force everywhere else.
- **`complexity` is deliberately NOT adopted** (Rule 2's third branch). Measured before
  adopting, its hits are characteristically false positives: a `switch` dispatching a
  dozen query operators to one-line cases scores ~15 cyclomatic while being trivially
  readable. Cyclomatic complexity counts branches, and a dispatch table is all branches and no
  complexity; splitting one to satisfy the rule makes the code worse. Adopt a *cognitive*
  complexity rule instead if the need is real.
- `eslint-plugin-import-x` (**not** `eslint-plugin-import`, which declares peer support
  only through eslint 9): `import-x/no-cycle`, plus `import-x/no-restricted-paths` to make
  the four-layer boundary above a build error instead of a review comment
  (controllers → application → infrastructure → domain; `domain/` imports nothing).
  Two things this rule needs, both of which produce a **silently passing** rule when
  missing, and both measured rather than assumed:
  - **A TypeScript resolver** (`eslint-import-resolver-typescript`, wired through
    `settings['import-x/resolver-next']`). Without one, not a single relative `.ts` import
    resolves and every zone check is skipped — the rule reports nothing, for ever.
  - **Zones derived from the modules on disk**, not globbed and not written per module.
    `target: './src/*/domain'` matches nothing; hard-coding one module's paths works until
    the second module is added and escapes the boundary unnoticed. Generate them from the
    layer ordering and `readdirSync('./src')`, and throw if the derivation yields none —
    a boundary rule with zero zones passes on everything.
- `eslint-plugin-jest`: `expect-expect` (a test that asserts nothing — the
  characteristic failure of generated tests) · `no-disabled-tests` ·
  `no-focused-tests` · `no-conditional-expect`.
- **A local rule worth authoring: a test may not import a *numeric* constant from the
  code it tests.** This is the lint half of "never build the expected value from the code
  under test": a threshold imported into a test makes the test move with the code, so
  changing `MAX_CONDITION_DEPTH` from 10 to 11 leaves the suite green while an observable
  limit changed — a mutation that survives suites that otherwise look thorough.
  Scoped to **numbers**, decided by the type checker rather than by naming, and the
  distinction is the whole reason it has no false positives: a number is a threshold whose
  value a caller observes, so a test must state it as a literal; a string / object / array
  constant is usually a registry or schema (the field list a DDL is generated from), where
  deriving is the point and hard-coding forty names would duplicate the source of truth.
  It lives inline in `eslint.config.mjs` — a rule this project-shaped needs no package —
  which is why the template cannot ship it as a `gates:` entry: a project that adopts it
  declares the gate in its own copy of this profile, and the literal must be the
  **activation line, severity included** (`'local/…': 'error'`), never the bare rule name,
  which also appears in the rule's definition and would match with the rule switched off.

  Why lint and not the drill: the drill finds a weak test after the fact and only when
  someone runs it, and it **cannot tell a weak test from a shortcut fix to one** — pinning
  `expect(MAX_CONDITION_DEPTH).toBe(10)` satisfies the drill while testing no behaviour at
  all. Lint refuses it at the moment of writing.

**Ratcheted** (aggregates; baseline kept outside the repo per Rule 3):
- **coverage** — `npm run test -- --coverage`; jest's `coverageThreshold` is the in-repo
  floor, the history lives in the metrics service. Set the floor to **what is measured
  today**, per metric, and raise it as work lands: the absolute value carries no claim,
  the direction does.
  Read the number honestly, because two things distort it. `collectCoverageFrom` counts
  declaration-heavy files (a DTO that is all field decorators, generated types), which
  drags statements down without any behaviour going unchecked; and the **e2e suite runs
  under its own jest config, so it contributes nothing to this number** — which is where
  most acceptance criteria are actually covered. A low statements floor beside a high
  branch floor is the expected shape, not a defect to explain away.
  With `## Test conventions` above in force, `application/` and `domain/` should measure
  at or near 100% on their own — a gap there is a missing unit spec, not noise; the drag
  on the aggregate comes from declaration-heavy files, never from untested logic.

**Dropped, with the reason** (Rule 2's third branch — a rule that does not hold here
is written down, never silently missing):
- **mutation score as a ratcheted metric.** Coverage proves a line ran, not that a
  test would fail if its behavior changed — so the gap is real. It is closed per-diff
  by the **mutation drill** ([`../references/tdd.md`](../references/tdd.md), step 7)
  with the agent as the mutation engine, not by a repo-wide score. Consequence, stated
  plainly: there is **no aggregate number** for test strength in this stack, and the
  drill is bounded to changed files — code that predates the drill is not covered by
  it. What buys the trade is that a diff-scoped drill needs no tool to own, no baseline
  to store, and no CI budget to defend.
- **Property-based testing** (`fast-check`) is the complement for `domain/` — pure
  types and rules with invariants. It tests the code with varied inputs; the drill
  tests the tests. Neither replaces the other.

**Escape hatches** (Rule 4 — named, justified, counted):
- `@typescript-eslint/ban-ts-comment` at `allow-with-description` — `@ts-expect-error`
  permitted with a reason, `@ts-ignore` never (expect-error expires by itself when the
  underlying error is fixed).
- `@eslint-community/eslint-plugin-eslint-comments`: `require-description` ·
  `no-unlimited-disable` · `no-unused-disable` — a suppression must name its rule and
  say why, and a stale one is an error rather than a fossil.
  **Its `recommended` preset is not enough**, measured: that preset enables five rules
  (`disable-enable-pair`, `no-aggregating-enable`, `no-duplicate-disable`,
  `no-unlimited-disable`, `no-unused-enable`) and **neither `require-description` nor
  `no-unused-disable` is among them**. Enabling the preset alone leaves the promise above
  unenforced while looking installed — turn both on explicitly.
- The repo-wide count of suppressions plus `as any` / `as unknown as` / `x!` is
  **ratcheted in-repo** — the one baseline Rule 3 allows inside the repository, because a
  suppression is source text and the ceiling bump shows up in the same diff. Patterns and
  ceilings go in `.escape-hatches.json`; enforced by `.inspire/bin/escape-hatch-ratchet.sh`
  from `pre-commit`.

Test-file relaxations are enumerated **per rule with a written reason**. Two legitimate
cases, and they are different in kind:

- **Untyped response boundaries** — HTTP/GraphQL payloads the types cannot prove. Debt:
  it shrinks as the boundary gets modelled.
- **Negative-path construction** — a test that feeds the wrong type to a validator
  (`null as unknown as string`) needs a cast, because the type system preventing it is
  the whole point of the code under test. **Structural, not debt**: its ratchet ceiling
  should hold, not drain, and the config should say so — a ceiling that invites a cleanup
  which cannot happen trains people to ignore it.

Never a blanket disable of the correctness rules for `**/*.spec.ts`.

## Build & verify
build: `npm run build` · lint: `npm run lint` · types: `npx tsc --noEmit` ·
tests: `npm run test` + `npm run test:e2e`

**Monorepo scoping.** In a workspace, scope every command to the target surface's
package: `pnpm --filter {package} build|lint|test` (or the workspace tool's
equivalent — `npm -w {package} …`, `turbo run test --filter={package}`, `nx test
{package}`). Never run a workspace-wide install or build from a subcommand when a
filtered form exists. E2E still runs against a real database — filter which package's
suite runs, never what it runs against.

**Test infrastructure — check before the first red test** (the precondition in
[`../references/tdd.md`](../references/tdd.md)). The components come from `stack.md`'s
`## Test infrastructure`; the compose file realizes them:

- Inspect: `docker compose config --services` — every declared component has a service.
- Status: `docker compose ps` — a service must be **healthy**, not merely `Up`. Compose
  services carrying a healthcheck report both, and `Up` is where a flaky e2e suite comes
  from: the container exists, the server is still opening its ports.
- **Ask the operator to run** `docker compose up -d` (or `--wait`, which blocks until
  healthchecks pass). Do not start it silently — they may have it up on other ports or
  pointed at a shared instance.
- Then run `npm run test:e2e` once. A connection error is **not** red; it is a suite that
  never ran.

## References

Deep material, read on demand — never load one whose topic the task does not touch:

- [`nestjs/references/testing.md`](nestjs/references/testing.md) — the spec-authoring
  conventions: GIVEN/WHEN/THEN grouping, stub-groups, typed auto-mocks, assertion
  discipline, per-spec helpers, the general rules. Read before writing or modifying
  any spec, mock, or assertion.
- [`nestjs/references/db-assertions.md`](nestjs/references/db-assertions.md) — worked
  e2e examples: read fixtures, domain→model/HTTP mappers, matcher helpers,
  `expectXInDb`, create/unchanged cases. Read when asserting persisted state.
- [`nestjs/references/error-assertions.md`](nestjs/references/error-assertions.md) —
  `toStrictEqual` with cause, custom exceptions, nested causes, anti-patterns. Read
  when asserting a throw or rejection.
- [`nestjs/references/nock-helpers.md`](nestjs/references/nock-helpers.md) — the
  static helper-class template for mocking external HTTP in e2e. Read when a test
  touches an external API.
- [`nestjs/references/coding-standards.md`](nestjs/references/coding-standards.md) —
  the audit-event rule in full, and typed invariants (`NonEmptyArray` + assertion
  functions). Read when writing a service mutation or a validated boundary.
