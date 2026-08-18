# Feature — acceptance-criteria quality gate
> Part of [inspire-feature](../SKILL.md). Read when the entry's index routes here.

## Acceptance-criteria quality gate

Acceptance criteria are the contract the coding stage tests against
([`/inspire_code tdd`](../../inspire-code/SKILL.md) turns each testable criterion into
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

Then a short **devil's advocate** pass — name at least a couple of ways the feature
could break that the criteria don't yet cover (malformed/missing data, an external
dependency down, two actors acting at once, boundary inputs) and turn each into a
missing criterion or an explicit out-of-scope note. Watch for **scope creep**: a
criterion that adds a requirement nobody asked for is a flag, not a feature.

Surface gaps concisely (e.g. `AC-2: "should be fast" → define: p95 < 200 ms`);
tighten with the operator; write the criteria only once they pass. A criterion that
cannot be made testable is usually a spec/design gap — resolve it here, or, if it
depends on a behavioral contract, chain to `/inspire_domain`.
