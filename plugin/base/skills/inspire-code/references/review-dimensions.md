# /inspire_code review — judgment review of a diff

Review a working diff (or a scoped target) for the things a linter **cannot** catch.
Mechanical checks belong to the toolchain, and one slipping through is a tooling gap
to fix rather than a thing to review by hand — the mechanical-checks rule in
[`../SKILL.md`](../SKILL.md) § Rules lists them. This skill spends its tokens only
on judgment.

`review` is **read-only**: it reports, ranks, and names the fix (and the skill to
run for it). It never edits code.

## Workflow

1. **Identify the change** — default to `git diff` / `git diff --cached`; a
   `<target>` may scope it to a path, a commit range, or a `<feature-id>`.
2. **Load the anchors** — the repo's `CLAUDE.md` files (primary coding source of
   truth), the relevant KB (the feature file(s), the action descriptor(s), and any
   ADR the change claims to realize), **and the active stack profile(s)** (SKILL.md
   → Stack profiles).
3. **Run Phase 0 inline**, then fan out phases 1–4 (see "Fan-out").
4. **Rank and report** in the output format below.

## Phase 0 — KB alignment (the INSPIRE differentiator)

This is what a generic code review does not do. Before judging the code on its own
terms, judge it against what the KB says it must be:

- **Acceptance criteria** (`03_features/{module}/{feature-id}.md`) — is every
  testable criterion the diff touches actually covered by a test?
- **Action descriptor** (`04_domain/{module}/{entity}/`) — does the code satisfy
  the contract: inputs, outputs, touched entities, invariants, declared error set?
  Flag behavior that exceeds or contradicts the descriptor.
- **ADR** (`01_adr`) — does the diff contradict a current ADR (present, not
  superseded or rejected) within its maturity's reach? If it claims to move an ADR to
  `implemented`, is the claim true?

A disagreement here is not automatically a code bug — it may be a spec gap. Classify
it: **code wrong → fix in the diff; spec wrong/missing → hand back** to
`/inspire_feature` / `/inspire_domain`. Render SDD-layer findings with the shared
format in [`../../_references/findings-format.md`](../../_references/findings-format.md).

## Phases 1–4 — universal quality (judgment only)

One phase, one lens. The active stack profile sharpens them where its sections say
it does — the section → generic-dimension mapping in
[`profiles/README.md`](../profiles/README.md).

### Phase 1 · Architecture & design
Layering (business logic out of controllers/components), shared logic living in a
shared place, abstractions justified rather than premature, single-responsibility
units whose boundaries validate their input.

### Phase 2 · Logic & correctness
Semantic duplication no linter sees (>~70% overlap across files); an algorithm
correct for *this* use case, not merely compiling; edge cases (null, empty, boundary,
concurrent access); error handling specific and at the right level, async paths
handling both failure and timeout.

### Phase 3 · Security
Hardcoded secrets; injection / XSS vectors (unsanitized input into the DOM, `eval`,
dynamic queries, external URLs used unsanitized); input validated at the boundary
with the *correct* constraints, not merely "a validator exists"; sensitive data in
logs or error responses; **authorization** checked, not only authentication.

### Phase 4 · Testing strategy
Tests of the right type for the layer, covering meaningful edge cases and not just
the happy path, following the conventions in [`tdd.md`](tdd.md) — GIVEN/WHEN/THEN,
behavior over implementation, one test = one scenario, mocks at the right boundary.

## Build verification

Confirm the change builds and tests pass, using the active stack profile's
`## Build & verify` commands when present, else the project's own. If the project
uses a private package registry and install fails with 401/403, authenticate first —
the command is project-specific (see [`fix-build.md`](fix-build.md)). Report
pass/fail per step; don't inline the raw output.

## Fan-out (thorough mode)

For a large or critical diff, run phases 1–4 as **parallel dimension agents**, one
per dimension, then synthesize — the same batch pattern `/inspire_module review`
uses. Each agent gets the diff + the loaded anchors and reports findings in the
row format below. The dimensions:

| Dimension | Focus (what the agent hunts for) |
|---|---|
| architecture | Clean-code / SOLID / DRY / KISS, layering, cyclomatic complexity, unjustified abstraction |
| correctness-chaos | Every way it breaks: edge cases, race conditions, partial failures, timeouts, corrupt state — run especially on critical flows (auth, payments, data mutations, integrations) |
| tests | Coverage of new logic, edge cases, mocking correctness, a regression test for each fix |
| duplication | Copy-pasted / >70%-similar logic across files; propose unification |
| dead-code | Unused exports/vars/types, orphaned files, commented-out blocks left behind by the change |
| surface-boundaries | Only when a surface roster exists (`00_bootstrap/surfaces.md`): an import reaching from one surface's `Package` path into another's — cross-surface sharing belongs in a `lib` package |

**Add one agent per active stack profile's `## Review focus` entry** (e.g.
api-contract, styling, a11y, security) — the stack-concrete lenses layered on top of
the universal dimensions above. A profile with no `## Review focus`, or no profile
at all, just means the universal set.

Scale to the change: a small diff runs inline; "review thoroughly" / a critical flow
runs the full fan-out. Keep dimensions read-only.

## Output format

```markdown
## Code Review — {target} | {date}

### KB alignment (Phase 0)
- ADRs: {ok | contradicts adr-xxx} · Descriptor: {satisfied | gap} · Acceptance criteria: {N/N covered}
- Hand-backs: {none | /inspire_domain <id>: <why>; /inspire_feature <id>: <why>}

### Tooling: lint {PASS/FAIL} · types {PASS/FAIL} · build {PASS/FAIL} · tests {PASS/FAIL}

### Issues (judgment-based)
| Severity | Category | File:Line | Description | Fix |
|---|---|---|---|---|
| BLOCKING | Security | src/foo:42 | Hardcoded API key | Move to env var |
| BLOCKING | Correctness | src/bar:15 | Race on concurrent update | Optimistic lock |
| WARNING | Architecture | src/baz:8 | Business logic in controller | Move to service — `/inspire_code tdd` |

### Verdict: READY | NEEDS FIXES ({n} blocking, {m} warnings)
```

`BLOCKING` = must fix before merge (security, correctness, KB contradiction).
`WARNING` = should fix. Always name the file:line and the concrete fix (and the
skill to run when the fix is a hand-back).
