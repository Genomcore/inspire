# /inspire-code tdd — write production code test-first

**No implementation without tests first.** This reference carries the attended loop:
the unit of work, the red-green-refactor cycle, and the KB anchoring around it. The
judgment it runs on is shared with the unattended loop and lives per role in
[`roles/`](roles/README.md).

The unit of work is a **feature**: `tdd {feature-id}` implements the use case at
`inspire_kb/03_features/{module}/{feature-id}.md`, and its **acceptance criteria
are the test list**. One testable criterion → at least one test. A criterion you
cannot write a test for is a spec problem — hand it back to `/inspire-feature`
before writing code.

> **Stack profile.** Resolve the active profile(s) first (SKILL.md → Stack
> profiles). When one is present, its `## Test conventions`, `## Layering`, and
> `## Forbidden patterns` refine the generic rules in [`roles/`](roles/README.md),
> and its `## Build & verify` gives the exact commands to run. No profile → those
> generic rules stand alone.

## Two roles, in sequence

Writing the test and writing the code are different positions, and each one's
doctrine has one home. Read it as you enter the position:

| step | role | what its doc carries |
|---|---|---|
| write the failing test | **tester** — [`roles/tester.md`](roles/tester.md) | test structure (GIVEN/WHEN/THEN), one test one scenario, mocking at the boundary |
| make it pass | **implementer** — [`roles/implementer.md`](roles/implementer.md) | the non-negotiable authoring rules, which bind every subcommand that writes code |

Attended, the list under test is the feature's acceptance criteria rather than a
unit's derived claims, and the separation between the two positions is discipline
rather than a harvest filter. The judgment is the same one `emanate` dispatches as
agents.

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
   contract. Do not invent behavior the KB doesn't state. Read the `**State:**`
   line while here — a feature still 🟡 Planned gets the In-progress offer
   *before* the first test is written (see *The state ladder advances from here*).
2. **Derive the test list, then write it as e2e** — the list is not invented, it is
   composed (see *The test list is derived* below). Write it at the **e2e level
   first**: the acceptance criteria describe what a caller observes, so that is the
   level they translate to. Run them; confirm they fail for the right reason (red).
3. **Implement the minimum** — the simplest code that passes; no speculative
   generality. Decomposition happens here, shaped by the design principles below
   (*SOLID, whatever the language*), and **each unit it creates is born through
   its own red → green micro-cycle**: the unit's test is written first, against the
   unit's contract, and seen red before the unit's body exists. Units are never
   backfilled after the code works — a test written against working code has proven
   the code runs, not that the test can fail.
4. **Verify** — the active profile's `## Build & verify` commands, or the project's
   own when there is no profile (green).
5. **Refactor** — with the tests as a safety net; re-run. This is where a SOLID
   violation the minimum implementation introduced gets paid down, not deferred.
6. **Level roll-call** — walk the diff and enumerate every unit it created or touched
   (services, repositories, entry points, helpers); map each one to the test level the
   active profile's `## Test conventions` assigns it, and confirm that spec exists and
   covers the new behavior. **A unit missing its spec is red, not debt** — the cycle
   does not close while any unit the decomposition created lacks the test its level
   demands. This step exists because the derived list (step 2) drives the e2e level,
   while decomposition happens in step 3 and refactoring in step 5: only a roll-call
   taken *after* both sees the units that actually exist. It is what makes green mean
   *covered everywhere*, not "the derived e2e list passed".
7. **Mutation drill** — with code and tests settled and the roll-call clean, check
   that the tests were *complete*: break the code on purpose and confirm they notice
   (see below). A survivor sends you back to step 2, never to step 3.

Steps 1–5 prove the code does what the criteria say. Step 6 proves **no unit shipped
untested**; step 7 proves the **tests would have caught it if the code were wrong** —
the one thing a green suite cannot tell you about itself. With all three proven, the
feature has earned its state advance — the closing offer below.

## The state ladder advances from here

The `**State:**` ladder (🟡 Planned → 🔵 In progress → 🟢 Implemented) is
`/inspire-feature update`'s to write — but the moments it turns on are visible only
from inside this cycle, so this skill **offers** the advance and never auto-writes
it. Two moments, one offer each:

- **Cycle start → 🔵 In progress.** At step 1, when the feature file still says
  🟡 Planned, offer the advance before the first test is written. This is not
  bookkeeping: `criteria-have-tests.sh` warns at 🟡 and blocks from 🔵 on, so a
  feature implemented while still Planned runs the whole cycle with its gate
  disarmed — exactly when the gate exists to act.
- **Cycle close → 🟢 Implemented.** After step 7, when the suite is green, the
  drill is clean, and `.inspire/bin/criteria-have-tests.sh
  inspire_kb/03_features/{module}` reports no finding for this feature — every
  criterion claimed by a `@covers` — offer the promotion. Promoting puts the
  linked ADRs on the hook too: `adr-maturity-matches-features.sh` holds each ADR
  a 🟢 feature cites to `implemented`, so the natural next offer is
  `/inspire-adr` on any that still say `design`.

On acceptance, chain into `/inspire-feature update {feature-id}` — the owning
skill presents the one-line diff and stamps the write; this skill still never
edits the KB. Declining is an answer, not an error: note it and move on. The
offer matters most in bulk flows (a clean-room implementation pass after
`/inspire-extract`), where no moment ever reads as "I am starting feature X now"
and an entire implemented module otherwise sits at 🟡 until someone notices by
hand.

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

## The mutation drill (step 7)

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

The three-phase shape, the one-scenario rule, behaviour-over-implementation, what
"the whole object" means for a collection, exact values over weak matchers and where
to mock: [`roles/tester.md`](roles/tester.md) § Test structure. Which tools and which
levels are the active profile's `## Test conventions`.

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

## Design principles — SOLID, whatever the language

SOLID governs every decomposition this skill produces, and it is **language-agnostic
by restatement, not by exemption**: the principles predate no language and depend on
none. Where there is no class, the unit is a module, a function, a service, a
package — the forces are identical. Stated as those forces, so they read the same in
any stack:

- **Single responsibility** — one reason to change per unit. The test smell is the
  giveaway: a unit whose spec needs two unrelated GIVENs is two units sharing a name.
- **Open/closed** — behavior grows by *adding* a unit, not by editing a conditional
  that grows a branch per case. A `switch` every new variant must revisit is the
  violation; a registry, a strategy, a handler table is the shape of the fix.
- **Liskov substitution** — whatever stands in for an abstraction honors its
  contract: no strengthened preconditions, no weakened postconditions, no surprise
  errors outside the declared set. This is the descriptor's `## Errors` discipline
  applied inward — a substitute that throws what the contract never declared fails
  callers the type system told to trust it.
- **Interface segregation** — depend on the narrow contract actually used, never on a
  wide surface for one method's sake. A test forced to stub ten members to exercise
  one is this violation, measured.
- **Dependency inversion** — business logic depends on abstractions it owns;
  concretions (the store, the transport, the framework) are injected at the edges.
  This is what makes the unit level of the test pyramid *possible*: a domain unit
  that news up its own repository can only ever be tested through the database.

They are judgment, not lint — which is exactly why they live here and in `review`
Phase 1 rather than in a toolchain rule (SKILL.md Rule 3 cuts the other way for
anything a machine *can* check). The active profile's `## Layering` is the
stack-concrete realization of the same forces; where profile and principle seem to
disagree, surface it — never quietly pick one.

## Non-negotiable authoring rules

They hold for **every** subcommand that writes code (`tdd`, `debug`'s fix,
`fix-build`), and they are what `review` flags when violated. Their one home is
[`roles/implementer.md`](roles/implementer.md) § Non-negotiable authoring rules; the
resolved framework profile's `## Forbidden patterns` adds what is specific to the
stack.

## A flaky test is fixed, never re-run

Why a suite nobody trusts is worth nothing, and the capture → rule-out → fix order
that gets one back: [`roles/tester.md`](roles/tester.md) § A flaky test is fixed,
never re-run.

## Anchoring back to the KB

- Each test traces to an **acceptance criterion**; if criteria and tests diverge,
  the feature file wins — update tests, or hand the criterion back to
  `/inspire-feature` if it's the criterion that's wrong.
- The implementation realizes an **action descriptor**; honor its inputs, outputs,
  touched entities, invariants, and declared error set. A behavior the code needs
  but the descriptor doesn't cover is a `/inspire-domain` hand-back, not an
  ad-lib.
