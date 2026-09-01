---
kind: inspire-code-profile
id: ios
layer: frontend
---

## Layering
Not yet formulated for this stack — deliberately deferred to an iOS iteration that
exercises real module boundaries, rather than transcribed untested from another
stack's rules. The contract in README.md still applies; this line is the deferral,
not the answer.

## Test conventions
- **Swift Testing** (`import Testing`), not XCTest, for new suites: `@Suite` per
  feature, `@Test("behavior description")` per case.
- `#expect` for assertions, `#require` for unwrapping optionals — a failed
  `#require` ends the test instead of cascading nil crashes.
- Arrange-Act-Assert structure; test behavior, never implementation.
- Parameterized cases via `@Test(arguments:)` instead of copy-pasted bodies:

  ```swift
  @Test("Item count formats correctly", arguments: [
      (0, "No items"),
      (1, "1 item"),
      (5, "5 items")
  ])
  func testPluralization(count: Int, expected: String) {
      let result = formatItemCount(count)
      #expect(result == expected)
  }
  ```

- Edge cases are part of the derived list: empty strings, nil, boundaries, and —
  specific to this stack — different locales.
- Keep tests fast (< 1 second each); slowness here is a design smell, not a fixture
  cost.

## Forbidden patterns
Not yet formulated for this stack — same deferral as Layering.

## Review focus
Not yet formulated for this stack — same deferral as Layering.

## Quality gates
Not yet formulated for this stack — the backend profile's gates were measured on a
real codebase and this stack has had no equivalent iteration
([`quality-gates.md`](../../_references/quality-gates.md) Rule 2 forbids transcribing
untested). The rules themselves still bind: a project on this stack derives its own
gates (SwiftLint rule set, coverage floor) from an iteration that exercises each rule
before writing it down. This section is the deferral, not the answer.

## Build & verify
tests: `swift test` · one test: `swift test --filter <testName>` ·
coverage: `swift test --enable-code-coverage` · parallel: `swift test --parallel`
