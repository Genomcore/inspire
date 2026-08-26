# /inspire-code debug — root-cause framework

**Never fix without understanding root cause.** A patch that makes the symptom go
away without an explained cause is drift waiting to recur.

> **Stack profile.** When one is active (SKILL.md → Stack profiles), use its
> `## Build & verify` commands to run the type-checker, tests, and build during
> elimination (step 3) and verification (step 6).

## 6 steps

### 1. Reproduce reliably
Pin the exact conditions before theorizing — the action, payload or call, the state
and data conditions, and (for a failing test) that it fails in isolation rather than
by ordering or environment. If you cannot reproduce it, that is finding #1: say so
and gather evidence instead of guessing at a fix.

### 2. Generate hypotheses (3–5)
Force breadth before depth, across the stack-neutral fault classes: state/data,
boundary/contract, timing/concurrency, configuration/environment, integration.

### 3. Systematic elimination
Test each hypothesis with **evidence**, not intuition — type-checker and linter
output, verbose test output, the data flow traced hop by hop, targeted logging
removed once the cause is found.

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
  `/inspire-feature update {feature-id}` (missing/updated acceptance criterion) or
  `/inspire-domain define|update {id}` (missing/ambiguous behavioral contract).
  Fixing code to paper over an unspecified behavior just moves the drift.

### 5. Fix
1. **Write a failing test first** that reproduces the bug (structure in
   [`tdd.md`](tdd.md)). The test is the proof you understood it.
2. Fix the **root cause**, minimally and without opportunistic refactors, following
   the project's standards and the authoring rules in [`tdd.md`](tdd.md) (never
   silence the toolchain, never swallow errors).

### 6. Regression prevention
1. Verify the new test passes, the failing scenario is gone, and the full suite is
   free of collateral breakage.
2. **Search for sibling patterns** — the same bug in adjacent code. Fix them, or
   file them as a tracker ticket via `/inspire-task`, never as an anonymous TODO.
3. If the cause was a non-obvious gotcha, capture *why* — in the test name, a short
   code comment, or, if it is a design lesson, an ADR (`/inspire-adr`) or the design
   system.

## Output

Report the cause, not just the fix:

```markdown
## Debug: {symptom}

**Reproduction.** {exact conditions}
**Root cause.** {fault class} — {WHY, one or two sentences}
**Scope.** {this site only | also at <paths>}
**Classification.** code | spec (→ handed to /inspire-feature|/inspire-domain)
**Fix.** {what changed} + regression test at {path}
**Verification.** failing test now passes; full suite {green | N pre-existing failures}
```
