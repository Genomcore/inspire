# /inspire_code tdd — write production code test-first

**No implementation without tests first.** This reference carries two things: the
red-green-refactor loop with its test conventions, and the non-negotiable authoring
rules that hold for *any* code this skill writes (not only under `tdd`).

The unit of work is a **feature**: `tdd {feature-id}` implements the use case at
`.inspire_kb/03_features/{module}/{feature-id}.md`, and its **acceptance criteria
are the test list**. One testable criterion → at least one test. A criterion you
cannot write a test for is a spec problem — hand it back to `/inspire_feature`
before writing code.

> **Stack profile.** Resolve the active profile(s) first (SKILL.md → Stack
> profiles). When one is present, its `## Test conventions`, `## Layering`, and
> `## Forbidden patterns` refine the generic rules below, and its `## Build &
> verify` gives the exact commands to run. No profile → the generic rules stand.

## Workflow

1. **Clarify** — read the feature file and any action descriptor
   (`04_domain/{module}/{entity}/`) that specifies the behavior. Extract inputs,
   outputs, and edge cases from the acceptance criteria and the descriptor's
   contract. Do not invent behavior the KB doesn't state.
2. **Write failing tests** — one per acceptance criterion, using the project's test
   framework. Run them; confirm they fail for the right reason (red).
3. **Implement the minimum** — the simplest code that passes. No speculative
   generality.
4. **Verify** — run the tests (and the build) using the project's commands (green).
5. **Refactor** — with the tests as a safety net. Clean up; re-run.

## Test structure: GIVEN / WHEN / THEN

Every test has three phases, blank-line separated:

```
it('describes one behavior', () => {
  // GIVEN   — setup; the method-under-test arguments come last, close to WHEN
  // WHEN    — a single statement exercising the logic under test
  // THEN    — the assertions; variables used only for assertions are defined here
})
```

- `// GIVEN`, `// WHEN`, `// THEN` are the only comments the test needs. Skip GIVEN
  when there is no setup.
- **One test = one scenario.** A single WHEN and one asserted outcome. Never bundle
  several calls into one test — split them.
- **Group assertions by concern**, one blank line between groups: returned value
  first, then each collaborator/dependency verification as its own group.
- **Test behavior, not implementation.** Assert observable outcomes and contract,
  not private internals. Prefer the most user-facing query available.
- **Assert the full shape, not fields piecemeal.** For a response body or a
  persisted document, assert the whole object; build the expected value from the
  domain entity, never from the value under test (comparing a result against itself
  proves nothing).
- **Prefer exact values over weak matchers.** Reach for "any"/"contains"/regex
  matchers only for values that are genuinely non-deterministic (generated ids,
  timestamps) — each weakening hides drift.

## Mocking

- **Mock at the boundary, not the internals.** Replace external systems (network,
  DB where the test isn't an integration test, third parties) — not the collaborators
  whose interaction you are trying to verify. Over-mocking tests the mocks.
- **Keep mock setup out of the test body where the project has a convention for it**
  (shared fixtures / builders / factories). Use test-data builders so each test
  specifies only the fields significant to it and lets the rest be defaulted.
- **Integration/e2e tests use the real thing** (real DB, real providers) and mock
  only the outermost external HTTP — verify the request was actually made.

## Choosing the test level

Match the test to the layer, not the file:

| Layer under test | Mock | Real |
|---|---|---|
| Business logic / services (unit) | its dependencies (repos, clients) | the logic itself |
| HTTP/entry boundary (integration) | external systems | the boundary + wiring |
| Data access against a store (integration) | external HTTP | the store itself |

## Non-negotiable authoring rules

These hold for **every** subcommand that writes code (`tdd`, `debug`'s fix,
`fix-build`), and they are what `review` flags when violated. They are the
generic, stack-agnostic core — the toolchain enforces the mechanical rest.

### Never silence the toolchain
Fix the root cause; do not gag the messenger. Forbidden as a default move:
disabling lint rules inline, suppressing type errors (`@ts-ignore` /
`@ts-expect-error` / equivalents), `as any`, `as unknown as X` casts that bypass a
real type error, non-null assertions (`x!`) that disable null-checking at the call
site, and formatter-ignore pragmas. If the type-checker or linter reports a
problem, treat it as a real defect: change the code, the type, or the design.
Narrow with a guard / `??` / a type guard instead of asserting. The only acceptable
use is a documented, reviewed, time-boxed escape hatch — never silent.

```ts
// Wrong — silences the symptom
const payload = response.data as any;
const email = user!.email;

// Right — model the type, and narrow explicitly
interface CreateUserResponse { id: string; email: string }
const payload: CreateUserResponse = response.data;
if (!user) throw new Error('user not found');
const email = user.email;
```

Where an invariant lives entirely in the type system (null-safety), encode it in
the signature (`NonNullable<T>`, a non-empty-array tuple) so misuse fails at compile
time — but keep the **runtime** check at the boundary layer, because external data
(JSON, request bodies, DB rows) is the realistic input and the type cannot prove it.

### Never swallow errors silently
A `catch` must do at least one of: re-throw (original or wrapped with `cause`),
handle meaningfully (fallback, compensating action), or log it when "do nothing" is
a conscious, explained choice. Empty `catch {}` blocks and `// swallow` comments are
forbidden — they make incidents undebuggable.

### Validate input at the boundary that owns it
Validate where the boundary is: at the entry DTO/schema when there is one, in the
application/service layer when there isn't. **Data-access code assumes valid input**
— pushing validation into it couples storage to domain rules and hides it from
callers.

### Never commit commented-out code
Delete it — git history is the archive. Exception: a single short comment explaining
*why* something non-obvious was removed.

### Never leave anonymous TODOs
A bare `// TODO` / `// FIXME` is forbidden. Every deferred item names an owner **and**
a closing trigger — and in INSPIRE the trigger is a real ticket:
`/inspire_task create`. If you can't name an owner or a trigger, it isn't
deferred, it's forgotten: do it now or open the ticket first.

## Anchoring back to the KB

- Each test traces to an **acceptance criterion**; if criteria and tests diverge,
  the feature file wins — update tests, or hand the criterion back to
  `/inspire_feature` if it's the criterion that's wrong.
- The implementation realizes an **action descriptor**; honor its inputs, outputs,
  touched entities, invariants, and declared error set. A behavior the code needs
  but the descriptor doesn't cover is a `/inspire_domain` hand-back, not an
  ad-lib.
