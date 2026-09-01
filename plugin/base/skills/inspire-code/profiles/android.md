---
kind: inspire-code-profile
id: android
layer: frontend
---

## Layering
Not yet formulated for this stack — deliberately deferred to an Android iteration
that exercises real module boundaries, rather than transcribed untested from another
stack's rules. The contract in README.md still applies; this line is the deferral,
not the answer. The test-level table below implies the working shape (ViewModel /
UseCase / Repository / DataSource), but the boundary rules are unwritten.

## Test conventions
- **JUnit 5** with one mock framework per project — MockK or Mockito, chosen once,
  never mixed in a suite.
- GIVEN/WHEN/THEN structure, backtick test names describing behavior:

  ```kotlin
  @Test
  fun `should return user when found by id`() {
      // GIVEN
      val userId = "user-123"
      val expectedUser = UserMother.random(id = userId)
      coEvery { repository.findById(userId) } returns expectedUser

      // WHEN
      val result = runTest { viewModel.loadUser(userId) }

      // THEN
      assertEquals(expectedUser, result)
      coVerify(exactly = 1) { repository.findById(userId) }
  }
  ```

- Test-data builders (`UserMother.random(...)`) — specify only the significant
  fields.
- Verify collaborator calls with exact counts (`coVerify(exactly = 1)` /
  `verify(repository, times(1))`), not just the returned value.
- **Levels:**

  | Layer | Framework | Mock strategy |
  |---|---|---|
  | ViewModel / state machine | JUnit 5 + mock framework | mock repository, use `TestDispatcher` |
  | Use case | JUnit 5 + mock framework | mock repository |
  | Repository | JUnit 5 + mock framework | mock DataSource/API |
  | Compose UI | Compose Testing | `createComposeRule()` |
  | Fragments/Activities | Espresso | `launchFragmentInContainer` |

- **Coroutines:** `runTest` + `TestDispatcher`; assert emitted states in order
  (`uiState.take(n).toList()`), not just the final value.

## Forbidden patterns
Not yet formulated for this stack — same deferral as Layering.

## Review focus
Not yet formulated for this stack — same deferral as Layering.

## Quality gates
Not yet formulated for this stack — the backend profile's gates were measured on a
real codebase and this stack has had no equivalent iteration
([`quality-gates.md`](../../_references/quality-gates.md) Rule 2 forbids transcribing
untested). The rules themselves still bind: a project on this stack derives its own
gates (detekt/ktlint rule set, a coverage floor via the jacoco report) from an
iteration that exercises each rule before writing it down. This section is the
deferral, not the answer.

## Build & verify
unit: `./gradlew test` (debug only: `./gradlew testDebugUnitTest`) ·
instrumented: `./gradlew connectedAndroidTest` · coverage: `./gradlew jacocoTestReport`
