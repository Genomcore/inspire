# Feature — acceptance-criteria quality gate
> Part of [inspire-feature](../SKILL.md). Read when the entry's index routes here.

## Acceptance-criteria quality gate

Acceptance criteria are the contract the coding stage tests against
([`/inspire-code tdd`](../../inspire-code/SKILL.md) turns each testable criterion into
a test). Weak criteria leak into weak tests and rework. So whenever criteria are
authored or changed — in `create` (before writing) and in `update` (when the
`## Acceptance criteria` change) — pass them through this gate first, as a Senior
Technical Product Owner would. It is a **judgment gate, not a subcommand**: run it
inline, show the operator what you'd tighten, and only write once the criteria hold.

Check each criterion on three dimensions:

- **Complete** — states the input/context, the expected observable outcome, and the
  error/edge behavior. Implicit requirements made explicit; scope (in / out) clear.
- **Testable** — a concrete test can be written from it alone; the result is
  measurable and observable; boundaries defined (empty, min, max, null); clear
  pass/fail. **Flag vague language** — "fast", "user-friendly", "appropriate", "as
  needed", "etc." — and replace it with a number or a concrete condition.
- **Verifiable** — checkable without reading the implementation; describes WHAT not
  HOW (stays functional, per the *functional, not technical* rule in
  [`../SKILL.md`](../SKILL.md) § Rules); no contradictions between criteria; happy
  path **and** error/edge paths covered.

Then check what the criteria **must not restate**, and what they **must** cover. The
line between the two is the project's resolved wire convention
([`_references/conventions/README.md`](../../_references/conventions/README.md)):

- **Do not write criteria for the convention's always-present cases.** "Returns 404 for
  an unknown id", "returns 401 without a token" — these hold for every action of the
  transport, `/inspire-code tdd` derives them, and restating them per feature is the
  duplication that drifts the day the convention changes.
- **Do write a criterion for every error the feature's actions declare** in their
  `## Errors`. That is the half a convention cannot derive, because the error is
  domain-specific. A declared error with no criterion is the gap this gate exists to
  catch.
- **Do write a criterion for anything that deviates** from the convention — a deviation
  is by definition not derivable.
- **Never work backwards from the test suite.** A test with no criterion is normal: it may
  come from the convention, from an ADR invariant, or from ordinary engineering (a unit
  test, a regression test, a security probe). Inventing a criterion to give such a test a
  home inflates the contract with programming conventions and is the failure mode this
  section guards against. The one honest reason to add a criterion from a test is that the
  test proves **user-observable behavior the feature genuinely forgot to state** — and
  then it is the feature that was incomplete, not the test that was orphaned.

Then a short **devil's advocate** pass — name at least a couple of ways the feature
could break that the criteria don't yet cover (malformed/missing data, an external
dependency down, two actors acting at once, boundary inputs) and turn each into a
missing criterion or an explicit out-of-scope note. Watch for **scope creep**: a
criterion that adds a requirement nobody asked for is a flag, not a feature.

Surface gaps concisely (e.g. `AC-2: "should be fast" → define: p95 < 200 ms`);
tighten with the operator; write the criteria only once they pass. A criterion that
cannot be made testable is usually a spec/design gap — resolve it here, or, if it
depends on a behavioral contract, chain to `/inspire-domain`.
