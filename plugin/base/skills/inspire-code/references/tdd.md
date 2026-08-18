# /inspire_code tdd — write production code test-first

**No implementation without tests first.** This reference carries two things: the
red-green-refactor loop with its test conventions, and the non-negotiable authoring
rules that hold for *any* code this skill writes (not only under `tdd`).

The unit of work is a **feature**: `tdd {feature-id}` implements the use case at
`inspire_kb/03_features/{module}/{feature-id}.md`, and its **acceptance criteria
are the test list**. One testable criterion → at least one test. A criterion you
cannot write a test for is a spec problem — hand it back to `/inspire_feature`
before writing code.

> **Stack profile.** Resolve the active profile(s) first (SKILL.md → Stack
> profiles). When one is present, its `## Test conventions`, `## Layering`, and
> `## Forbidden patterns` refine the generic rules below, and its `## Build &
> verify` gives the exact commands to run. No profile → the generic rules stand.

## Workflow

1. **Clarify against the KB** — read the feature file and any action descriptor
   (`04_domain/{module}/{entity}/`) that specifies the behavior. Take the inputs,
   outputs and edge cases from the acceptance criteria and the descriptor's
   contract. Do not invent behavior the KB doesn't state.
2. **Red → green → refactor** — one failing test per criterion, confirmed to fail
   for the right reason; then the simplest code that passes; then cleanup behind the
   tests. Verify with the active profile's `## Build & verify` commands, or the
   project's own when there is no profile.

## Test structure: GIVEN / WHEN / THEN

Every test has three phases, blank-line separated:

```
it('describes one behavior', () => {
  // GIVEN   — setup; the method-under-test arguments come last, close to WHEN
  // WHEN    — a single statement exercising the logic under test
  // THEN    — the assertions
})
```

- **One test = one scenario.** A single WHEN and one asserted outcome; never bundle
  several calls into one test.
- **Test behavior, not implementation.** Assert the observable outcome and the
  contract, not private internals — and build the expected value from the domain
  entity, never from the value under test.
- **Mock at the boundary, not the internals.** Replace external systems, never the
  collaborators whose interaction is the thing being verified. Integration/e2e tests
  use the real thing and mock only the outermost external HTTP.

Which tools, which levels, and how they run are the active profile's
`## Test conventions`.

## Non-negotiable authoring rules

These hold for **every** subcommand that writes code (`tdd`, `debug`'s fix,
`fix-build`), and they are what `review` flags when violated. They are the
generic, stack-agnostic core — the toolchain enforces the mechanical rest.

- **Never silence the toolchain.** A lint disable, a suppressed type error
  (`@ts-ignore` / `@ts-expect-error`, `as any`, a cast that bypasses a real error,
  a non-null assertion), or a formatter-ignore pragma treats a real defect as noise.
  Change the code, the type or the design instead, and narrow with a guard. The only
  acceptable use is a documented, reviewed, time-boxed escape hatch — never a
  silent one.
- **Never swallow errors silently.** A `catch` re-throws (original, or wrapped with
  `cause`), handles meaningfully, or logs a "do nothing" that was a conscious,
  explained choice. An empty `catch {}` makes incidents undebuggable.
- **Validate input at the boundary that owns it** — the entry DTO/schema where there
  is one, the application/service layer where there isn't. Data-access code assumes
  valid input; pushing validation into it couples storage to domain rules and hides
  it from callers.
- **Never commit commented-out code.** Git history is the archive; the exception is
  a short comment explaining *why* something non-obvious was removed.
- **Never leave anonymous TODOs.** Every deferred item names an owner **and** a
  closing trigger — and in INSPIRE the trigger is a real ticket:
  `/inspire_task create`. If you can name neither, it isn't deferred, it's
  forgotten: do it now, or open the ticket first.

## Anchoring back to the KB

- Each test traces to an **acceptance criterion**; if criteria and tests diverge,
  the feature file wins — update tests, or hand the criterion back to
  `/inspire_feature` if it's the criterion that's wrong.
- The implementation realizes an **action descriptor**; honor its inputs, outputs,
  touched entities, invariants, and declared error set. A behavior the code needs
  but the descriptor doesn't cover is a `/inspire_domain` hand-back, not an
  ad-lib.
