# /inspire_code tdd — write production code test-first

**No implementation without tests first.** This reference carries the attended loop:
the unit of work, the red-green-refactor cycle, and the KB anchoring around it. The
judgment it runs on is shared with the unattended loop and lives per role in
[`roles/`](roles/README.md).

The unit of work is a **feature**: `tdd {feature-id}` implements the use case at
`inspire_kb/03_features/{module}/{feature-id}.md`, and its **acceptance criteria
are the test list**. One testable criterion → at least one test. A criterion you
cannot write a test for is a spec problem — hand it back to `/inspire_feature`
before writing code.

> **Stack profile.** Resolve the active profile(s) first (SKILL.md → Stack
> profiles). When one is present, its `## Test conventions`, `## Layering`, and
> `## Forbidden patterns` refine the generic rules below, and its `## Build &
> verify` gives the exact commands to run. No profile → the generic rules stand.

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

## Workflow

1. **Clarify against the KB** — read the feature file and any action descriptor
   (`04_domain/{module}/{entity}/`) that specifies the behavior. Take the inputs,
   outputs and edge cases from the acceptance criteria and the descriptor's
   contract. Do not invent behavior the KB doesn't state.
2. **Red → green → refactor** — one failing test per criterion, confirmed to fail
   for the right reason; then the simplest code that passes; then cleanup behind the
   tests. Verify with the active profile's `## Build & verify` commands, or the
   project's own when there is no profile.

## Anchoring back to the KB

- Each test traces to an **acceptance criterion**; if criteria and tests diverge,
  the feature file wins — update tests, or hand the criterion back to
  `/inspire_feature` if it's the criterion that's wrong.
- The implementation realizes an **action descriptor**; honor its inputs, outputs,
  touched entities, invariants, and declared error set. A behavior the code needs
  but the descriptor doesn't cover is a `/inspire_domain` hand-back, not an
  ad-lib.
