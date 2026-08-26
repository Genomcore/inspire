# /inspire-code tdd — write production code test-first

**No implementation without tests first.** This reference carries two things: the
red-green-refactor loop with its test conventions, and the non-negotiable authoring
rules that hold for *any* code this skill writes (not only under `tdd`).

The unit of work is a **feature**: `tdd {feature-id}` implements the use case at
`inspire_kb/03_features/{module}/{feature-id}.md`, and its **acceptance criteria
are the test list**. One testable criterion → at least one test. A criterion you
cannot write a test for is a spec problem — hand it back to `/inspire-feature`
before writing code.

> **Stack profile.** Resolve the active profile(s) first (SKILL.md → Stack
> profiles). When one is present, its `## Test conventions`, `## Layering`, and
> `## Forbidden patterns` refine the generic rules below, and its `## Build &
> verify` gives the exact commands to run. No profile → the generic rules stand.

## Precondition: the test infrastructure runs, or the cycle cannot start

E2E tests are the first thing written, and they need something real to run against —
the database, the broker, the cache. **No infrastructure, no red; no red, no TDD.** So
this is a gate before step 1, not a chore discovered at step 2:

1. **Read what the tests need** from `00_bootstrap/stack.md` (`## Data`, messaging, and
   the local-dev-database choice). That is the declared inventory; the compose file is
   its realization, not its source of truth.
2. **Compare it against the compose file** in the product repo. Every declared component
   the e2e suite touches has a service. A component in `stack.md` and not in compose is
   the defect — a suite that cannot run, discovered halfway through writing it.
3. **A new component is a KB edit first.** Needing Redis, a second database or a broker
   is not a compose edit: it is a stack change. Record it in `stack.md` (and an ADR when
   it is load-bearing — `stack.md` is explicit that replacing a load-bearing choice is an
   ADR), *then* add the service. Compose follows the decision; it never stands in for it.
4. **Ask the operator to bring it up. Never assume it is running, never start it
   silently.** Long-running infrastructure is theirs to own: they may have it up already,
   on other ports, or against a shared instance. Print the exact command and wait.
5. **Verify, then start.** Run the e2e suite once before writing anything. It must fail
   for the *right* reason — an assertion, not a connection refused. A connection error is
   not red; it is a suite that never ran, and treating it as red is how an
   implementation gets written against tests nobody has seen fail.

The concrete commands and service names belong to the stack profile's
`## Build & verify`; this precondition is the stack-agnostic part.

## Workflow

1. **Clarify against the KB** — read the feature file and any action descriptor
   (`04_domain/{module}/{entity}/`) that specifies the behavior. Take the inputs,
   outputs and edge cases from the acceptance criteria and the descriptor's
   contract. Do not invent behavior the KB doesn't state.
2. **Derive the test list, then write it as e2e** — the list is not invented, it is
   composed (see *The test list is derived* below). Write it at the **e2e level
   first**: the acceptance criteria describe what a caller observes, so that is the
   level they translate to. Run them; confirm they fail for the right reason (red).
3. **Implement the minimum** — the simplest code that passes; no speculative
   generality. Decomposition happens here, and **each unit it creates is born through
   its own red → green micro-cycle**: the unit's test is written first, against the
   unit's contract, and seen red before the unit's body exists. Units are never
   backfilled after the code works — a test written against working code has proven
   the code runs, not that the test can fail.
4. **Verify** — the active profile's `## Build & verify` commands, or the project's
   own when there is no profile (green).
5. **Refactor** — with the tests as a safety net; re-run.
6. **Mutation drill** — with code and tests settled, check that the tests were
   *complete*: break the code on purpose and confirm they notice (see below). A
   survivor sends you back to step 2, never to step 3.

Steps 1–5 prove the code does what the criteria say. Step 6 proves the **tests would
have caught it if it didn't** — the one thing a green suite cannot tell you about
itself.

## The test list is derived, not invented

Before writing a line, compose the list from three sources. Two of them are already
written down; the third is what stops the list depending on whoever authored the
feature file remembering the boring cases.

1. **The acceptance criteria** — `03_features/{module}/{feature-id}.md`. One testable
   criterion → at least one test, and the test **claims** it with
   `/** @covers {feature}/AC-{n} */` above it — the id **qualified by the owning
   feature's filename stem** (`@covers ANL-02/AC-3`, never a bare `@covers AC-3`:
   `AC-3` recurs in every feature, and the gate accepts only the qualified form).
   The id stays out of the test name: names are read on every CI failure, so
   they hold a sentence about behavior (ideally the criterion's own words) while the
   annotation carries the traceability. Enforced by
   `.inspire/bin/criteria-have-tests.sh` — warning while the feature is 🟡 Planned,
   blocking from 🔵 In progress on, because that is when work has started and the first
   act of TDD is the test. A criterion you cannot write a test for is a spec problem;
   hand it back before writing code.
2. **Every error the descriptor declares** — each bullet in the action descriptor's
   `## Errors` is a test. A declared error with no test is a contract nobody checks, and
   this one is **enforced**: `.inspire/bin/declared-errors-tested.sh` requires the error
   code to appear as a literal in a test file — warning while the action is `draft`,
   blocking from `accepted` on. Asserting the exact code is what the wire convention
   asks for anyway, so satisfying the gate and satisfying the convention are one act.
3. **The resolved wire convention's always-present cases** —
   [`../../_references/conventions/README.md`](../../_references/conventions/README.md),
   resolved from `00_bootstrap/stack.md`'s `wire_conventions:`. Unknown id on a
   fetch, absent credential, valid credential without the permission, empty list,
   no stacktrace in an error body. These hold whether or not a criterion mentions them.
4. **The invariants of any ADR the feature realizes** — a read-only transport exposing no
   write, an append-only store never updating in place. These are architectural
   guarantees, so they belong to the ADR and not to any one use case; a feature file that
   restated them would drift from the ADR the moment it changed.

**Only source 1 needs a criterion.** Sources 2–4 produce tests that no acceptance
criterion mentions, and that is correct rather than a gap: writing a criterion for "an
unknown id returns not-found" pushes a programming convention into the feature file, which
is the duplication the convention layer exists to remove. `criteria-have-tests.sh` is
one-directional for this reason — it asks whether each criterion is tested, never whether
each test is specified. Beyond these four sources, ordinary engineering tests (unit tests
of the decomposition, a regression test for a fixed bug, a security probe) need no
justification from the KB at all.

The convention also supplies **what each case asserts**: the descriptor declares the
logical error (`missing_required_field`), the convention says what a caller observes
(which status, which code, which envelope). Neither alone is enough to write the test,
and inventing the missing half is what makes two engineers write two different contracts
for the same spec. **No convention resolved → say so and stop**; do not guess a status
code and then pin the guess with a test.

Where the descriptor carries a `**Wire deviation:**` note, that note wins over the
convention. Where it does not, the convention holds — that is what makes it restrictive.

## The test boundary

**A test starts when the entry point is invoked and ends with the response.** That
single sentence decides most mocking arguments before they start.

Inside the boundary — asserted, in full:

- The **response**, whole. Not a field or two out of the envelope.
- What was **persisted**: the full stored record, built from the domain entity, not from
  the value under test.
- What was **sent outward**: the third-party request that was made — its URL, method and
  body — not merely that a mock existed.
- What was **published**: the full payload of each emitted event or message, and its
  topic/key. An event is an output of the action; an unasserted publish is an untested
  output.

Outside the boundary — mocked, and deliberately not followed:

- Third-party APIs. We do not own them; their behavior is a fixture, and the interesting
  assertion is what *we* sent.
- Event consumers. The action's job ended when the event was published. Whether a
  downstream consumer handled it is that consumer's own test, at its own boundary.
- Anything asynchronous that continues after the response is returned — chase it and the
  test becomes a slow, flaky integration test of the whole system, failing for reasons
  that have nothing to do with the action under test.

The rule cuts both ways: **stopping short is as wrong as going too far.** An action that
saves a row, calls a payment provider and emits an event has three outputs plus its
response. A test asserting only the response passes while two of the four are broken.

## The mutation drill (step 6)

A green suite proves the tests *ran*. It cannot prove they would have **failed** had
the code been wrong — and that is the characteristic defect of generated tests: they
execute the line and assert nothing that pins its behavior down. The drill closes that
hole with the agent as the mutation engine, scoped to the change. It is a **check, not
a metric**: no score, no baseline, no ratchet ([`../../_references/quality-gates.md`](../../_references/quality-gates.md)).

**Preconditions.** The suite is green and the working tree is clean of unrelated
edits. Never drill on a red suite — a survivor means nothing when tests already fail.

**Scope.** Only the files this change touched, and within them the lines that carry
the acceptance criteria's behavior. Budget **k = 5–10 mutations per diff**, spent on
the layers where a silent wrong answer is worst: business logic and domain rules
first, wiring and DTOs last. This bound is the whole reason no tool is needed — the
performance engineering that a general mutation-testing tool exists to solve does not
apply to ten mutants.

**Catalogue** — targeted, judgment-chosen, never random. Judgment is what makes ten
mutants worth more than a thousand:

| Mutation | What a survivor tells you |
|---|---|
| Boundary: `>` ↔ `>=`, `<` ↔ `<=` | No test sits *on* the limit |
| Condition: invert a predicate, `&&` ↔ `\|\|` | A branch is entered but never asserted |
| Return the empty/default value (`[]`, `null`, `0`, the unmapped input) | The assertion accepts any shape |
| Delete an `await` | Nothing observes the ordering or the rejection |
| Delete a side-effecting call (a save, an emit, a log-and-continue) | A collaborator call is unverified |
| Swap two same-typed arguments | The mapping is asserted against itself |
| Error branch → success branch (drop a `throw`) | The declared error set is untested |

**Procedure.** One mutation at a time: apply it, run only the tests that cover the
file (the profile's `## Build & verify` commands, narrowed), record **killed** (a test
failed) or **survived** (all green), then **revert before the next one**. Never hold
two mutations at once, never leave one in the tree, and never commit with one applied
— finish by confirming `git diff` matches the pre-drill state exactly. Discard rather
than count: a mutation that fails to compile, and one that is semantically identical
to the original (it proves nothing either way). A mutated loop condition can hang —
run with a timeout and treat a timeout as killed.

**Reading the result.** Every survivor is a **test gap, not a code bug**: the code was
right before you broke it. Go back to step 2 and write the test that kills it, then
re-run the drill. Report survivors as `file:line — mutation applied → the test that
was missing`; a diff whose drill found nothing says the tests are load-bearing, which
is the only claim worth making at the end of a TDD cycle.

**This is the one practice here with no mechanical enforcement, and that is stated rather
than hidden.** Every other practice in this reference is backed by a gate that fails a
build: `criteria-have-tests.sh`, `declared-errors-tested.sh`, the escape-hatch ratchet,
the profile's test-lint rules. The drill is prose, and prose depends on someone running it.

Two consequences worth holding:

- **It is deliberate, not optional.** Where the stack profile drops mutation testing as a
  ratcheted metric (its `## Quality gates`), the drill is what replaces it. Skipping it
  does not fall back to something else — it falls back to nothing.
- **Write down a practice you rely on even when it already happens.** A practice that runs
  only because the agent happens to run it is neither scoped to the project nor removable
  from it — the inverse of the "written but not in force" failure, and easier to miss.
  This section exists so the drill is neither.

What partially covers the gap mechanically: a test-lint rule against assertion-free tests
(`expect-expect` or the stack's equivalent) refuses a test that asserts nothing, and a
rule against importing numeric constants from the unit under test (see the stack profile)
refuses a test that moves with the code. Neither replaces the drill — they close the two
vacuity shapes that recur, and the drill is what finds the rest.

**What complements it, cheaply.** For pure functions with invariants — `domain/`
logic, parsers, mappers — property-based testing (`fast-check` or the stack's
equivalent) covers the orthogonal axis: the drill varies the *code* to test the tests,
properties vary the *inputs* to test the code. Neither substitutes for the other, and
random inputs behind a weak assertion still prove nothing.

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
- **For a collection or paginated response, "the whole object" is the envelope plus the
  identity and order of the members** — not every field of every member. Asserting 200
  records × 40 fields is unmaintainable and breaks on every unrelated field addition, so
  it degrades into `toHaveLength`, which is the real failure. Assert instead: the
  envelope's **exact key set** (no extra, no missing), the members' **natural keys in
  order**, and the paging fields. A count alone cannot tell a correct page from an
  off-by-one that returned the same number of wrong rows — and that mutation is the one
  a paging bug actually is. Each member's field shape is the subject of the
  single-record tests; re-asserting it per member buys nothing.
- **Prefer exact values over weak matchers.** Reach for "any"/"contains"/regex
  matchers only for values that are genuinely non-deterministic (generated ids,
  timestamps) — each weakening hides drift.
- **Mock at the boundary, not the internals.** Replace external systems, never the
  collaborators whose interaction is the thing being verified. Integration/e2e tests
  use the real thing and mock only the outermost external HTTP.

Which tools, which levels, and how they run are the active profile's
`## Test conventions`; with no profile, match the test to the layer under test, not
the file.

## Choosing the test level

Match the test to the layer, not the file:

| Layer under test | Mock | Real |
|---|---|---|
| Business logic / services (unit) | its dependencies (repos, clients) | the logic itself |
| HTTP/entry boundary (integration) | external systems | the boundary + wiring |
| Data access against a store (integration) | external HTTP | the store itself |

**An e2e case earns its round trip, or it moves down a level.** The e2e suite carries
the **contract**: the derived list (criteria ∪ declared errors ∪ the wire convention's
always-present cases ∪ ADR invariants), the happy path, and the boundaries a caller can
observe that genuinely need the real stack. It does **not** enumerate business-logic
branches: those are the unit tests' job, on the service or domain unit that owns the
branch, where a case costs milliseconds instead of a real-store round trip. Two symptoms
that a case is at the wrong level: an e2e whose reason-to-exist traces to no entry in the
derived list, and the same assertion appearing at both levels — the duplicate buys
suite-minutes and proves nothing the cheaper level had not proven. An e2e suite that
grows by branches instead of by contract is the suite that eventually takes an hour, and
the response to that is never "run fewer tests" — it is this rule, applied earlier.

**The e2e tree mirrors the knowledge base's module structure** — `test/{module}/…` —
never a flat directory that every feature appends to. Cross-cutting probes that belong
to no module (the readiness probe, the API-documentation contract) live under
`test/platform/`, and shared harness code under `test/support/`. The unit tests need no
such rule: they are colocated with the unit they test, which is what keeps them next to
the decomposition that created them.

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
  it from callers. A type signature cannot prove external data (JSON, request
  bodies, DB rows) — the boundary check stays even where the type system already
  encodes the invariant.
- **Never commit commented-out code.** Git history is the archive; the exception is
  a short comment explaining *why* something non-obvious was removed.
- **Never leave anonymous TODOs.** Every deferred item names an owner **and** a
  closing trigger — and in INSPIRE the trigger is a real ticket:
  `/inspire-task create`. If you can't name an owner or a trigger, it isn't
  deferred, it's forgotten: do it now, or open the ticket first.

**A flaky test is fixed, never re-run.**
**A test that fails and passes on the next run is a defect, and the flakiness is the defect
— not the run that caught it.** Fix it before continuing with anything else. Re-running to
get green is forbidden, and so is recording the failure as unexplained and moving on.

The reason is not tidiness. Every mechanical gate in a project is worth exactly what a red
result is worth. One test that fails at random teaches everybody — operator and agent alike
— that red might mean nothing, and from then on the honest failures get re-run too. A suite
that is 99% reliable is not 99% as useful as a reliable one; it is a suite nobody reads.

So, in order:

1. **Capture the failure first.** Root cause before fix (Rule 4) has no exception here, and
   an intermittent bug is exactly where a plausible guess is most expensive: it "works"
   afterwards whether or not it was the cause, and the next occurrence is weeks away. Loop
   the suite retaining each run's output until one goes red, and read *that* output.
2. **Rule causes out with evidence, and say which you ruled out.** "The suites run in
   parallel" is checkable in one line; asserting it without checking sends the fix in the
   wrong direction and leaves the reader unable to re-derive the reasoning.
3. **Only then fix**, and prove it by looping the suite again — a fix for an intermittent
   failure is not verified by one green run, which is the state the bug already produced.

The usual causes, in the order they are worth suspecting for an e2e suite against a real
store: shared mutable state between test files, DDL or setup racing itself, a read issued
before the write it depends on is visible, and time or ordering assumed rather than
controlled.

## Anchoring back to the KB

- Each test traces to an **acceptance criterion**; if criteria and tests diverge,
  the feature file wins — update tests, or hand the criterion back to
  `/inspire-feature` if it's the criterion that's wrong.
- The implementation realizes an **action descriptor**; honor its inputs, outputs,
  touched entities, invariants, and declared error set. A behavior the code needs
  but the descriptor doesn't cover is a `/inspire-domain` hand-back, not an
  ad-lib.
