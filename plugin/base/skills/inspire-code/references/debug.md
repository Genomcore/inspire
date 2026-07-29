# /inspire_code debug — root-cause framework

**Never fix without understanding root cause.** A patch that makes the symptom go
away without an explained cause is drift waiting to recur.

> **Stack profile.** When one is active (SKILL.md → Stack profiles), use its
> `## Build & verify` commands to run the type-checker, tests, and build during
> elimination (step 3) and verification (step 6).

## 6 steps

### 1. Reproduce reliably
Pin the exact conditions before theorizing.
- **UI / client:** the exact user action, component state, and data conditions.
- **Service / backend:** the exact call, payload, and observed response.
- **Test:** run it in isolation to confirm the failure is consistent, not ordering-
  or environment-dependent.

If you cannot reproduce it, that is finding #1 — say so and gather more evidence
rather than guessing at a fix.

### 2. Generate hypotheses (3–5)
Force breadth before depth. Typical fault classes, stack-neutral:
- **State / data:** stale value, wrong transformation, mutation of shared state.
- **Boundary / contract:** input not validated, output shape drifted from the
  consumer's expectation, null/empty/edge value.
- **Timing / concurrency:** race between async operations, missing await, unhandled
  rejection, retry storm, ordering assumption.
- **Configuration / environment:** wrong flag, missing env var, differing behavior
  across environments.
- **Integration:** an external dependency returned an error, timed out, or changed
  its response.

### 3. Systematic elimination
Test each hypothesis with **evidence**, not intuition:
- Run the type-checker and the linter; read verbose test output.
- Trace the data flow end-to-end: `Input → Transform → Output`, checking the value
  at each hop.
- Add targeted logging at the decision points, then remove it once the cause is
  found.

### 4. Identify root cause
Explain **WHY**, not just WHERE. Name the fault class (logic error, type mismatch,
missing edge case, race condition, stale data, misconfiguration). Then ask the
question that prevents the next bug: **does the same pattern exist elsewhere?**

**SDD loop-back — the INSPIRE-specific step.** Decide whether the cause is *code*
or *spec*:
- **Code cause** → fix it here (step 5).
- **Spec cause** — the behavior the code got "wrong" was never actually specified,
  or the acceptance criterion is ambiguous/absent, or an action descriptor's
  contract is silent on this case → **stop and hand back.** Route to
  `/inspire_feature update {feature-id}` (missing/updated acceptance criterion) or
  `/inspire_domain define|update {id}` (missing/ambiguous behavioral contract).
  Fixing code to paper over an unspecified behavior just moves the drift.

### 5. Fix
1. **Write a failing test first** that reproduces the bug (see
   [`tdd.md`](tdd.md) for structure). The test is the proof you understood it.
2. Fix the **root cause**, not the symptom.
3. Keep the change **minimal and focused** — no opportunistic refactors riding
   along.
4. Follow the project's coding standards and the authoring rules in
   [`tdd.md`](tdd.md) (never silence the toolchain, never swallow errors).

### 6. Regression prevention
1. Verify the new test passes and the previously failing scenario is gone.
2. Run the full test suite — confirm no collateral breakage.
3. **Search for sibling patterns** — the same bug in adjacent code. Fix or file
   them (a tracker ticket via `/inspire_task`, not an anonymous TODO).
4. If the cause was a non-obvious gotcha, capture *why* — in the test name, a short
   code comment, or, if it is a design lesson, an ADR (`/inspire_adr`) or the design
   system.

## Common trace paths

| Symptom | Trace path |
|---|---|
| Wrong data shown / returned | source → transform/mapping → boundary (response) → consumer render |
| Passes locally, fails in CI | test ordering, timing, environment differences, mock/fixture setup |
| Type error | type-check output → the actual type shapes → imports/exports |
| Intermittent failure | async completion, unhandled rejection, shared mutable state, race |
| Integration failure | request built correctly? external response mocked/handled? timeout + error path? |

## Output

Report the cause, not just the fix:

```markdown
## Debug: {symptom}

**Reproduction.** {exact conditions}
**Root cause.** {fault class} — {WHY, one or two sentences}
**Scope.** {this site only | also at <paths>}
**Classification.** code | spec (→ handed to /inspire_feature|/inspire_domain)
**Fix.** {what changed} + regression test at {path}
**Verification.** failing test now passes; full suite {green | N pre-existing failures}
```
