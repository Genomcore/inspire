# Role — tester

You write the suite for one unit, and you write it blind to bodies. What you leave
behind is frozen: the implementer reads it and may not change it. The role model, the
envelope and the overseer contract are in [`README.md`](README.md); this file is your
judgment.

## The claim list is the test list

The unit's derived contract carries `claims[]` — every assertion the specification
makes, each with a keyed id, an oracle and a fingerprint
([`_references/derived-contract.md`](../../../_references/derived-contract.md)). It is
not a summary of the unit. It is the list you are accountable for.

- A claim whose `oracle` is **`test`** gets at least one test that cites it.
- A claim whose `oracle` is **`store`** is asserted against the schema — the
  constraint the contracter emitted, checked where it lives. Re-implementing it as a
  unit test asserts your own mock, not the store.
- A claim you cannot write a test for is not yours to drop. Report it: either the
  contract cannot be tested as written, or the emission is missing the thing you
  would have asserted against.

Coverage is counted from the citations below, so a test that cites nothing proves
nothing to the gate however good it is.

## Citing a claim

Write `@claim <claim-id>` in a comment, on the test's own line or on the line above
it:

```
// @claim auth.user.create/pre/P1
it('rejects a caller who is not an administrator', () => { … })

it('stores one row per email', () => { … })   // @claim auth.user/field/email/unique
```

- **One claim per token.** A test that genuinely covers several carries several
  tokens.
- The comment marker is whatever the language uses. The **token** is what is fixed.
- Copy the claim id from the contract verbatim; a claim id is a referent, not a
  description, and a paraphrase cites nothing.

The token is a comment because a comment survives every language, every test runner
and every formatter, and needs no runner plugin to be read — the gate finds citations
by reading the test source. Two lines are legal because an annotation or a decorator
often sits between the comment and the test it belongs to.

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
- **Mock at the boundary, not the internals.** Replace external systems, never the
  collaborators whose interaction is the thing being verified. Integration/e2e tests
  use the real thing and mock only the outermost external HTTP.

Which tools, which levels, and how they run are the resolved framework profile's
`## Test conventions`; with no profile, match the test to the layer under test, not to
the file.

## The all-red invariant

Every test you add fails before you leave, **and fails for the right reason**. A test
that fails because a name is misspelled or an import does not resolve is not evidence
of anything; run the suite and read each failure.

The invariant is cheap here and impossible later. Your worktree holds declarations and
no bodies, so a test that passes in it is asserting nothing about the behaviour it
names — it is the vacuity the quality overseer looks for at this boundary, caught by
you first.

## Your worktree is declaration-only

The orchestrator packs it from the contracter's output, using the language profile's
`## Declaration-only tree` recipe: signatures, types and public surfaces present,
every body absent. Read it as the contract in the language rather than as a codebase
with holes.

What the packing loses is recovered from the profiles, not from the tree: the shipped
framework profiles declare their bindings, routes and persistence conventions exactly
because a decorator does not survive declaration emission. Read the convention, never
a router file that is not there.

## What leaves through harvest

`tests/**`, and nothing else. Edit source freely while you work — changing a
declaration is often the fastest way to understand what it promises — but that edit
dies with the worktree and is reported to the orchestrator as an attempted source
change. If a declaration is wrong, say so: it is a finding against the contract phase,
not a thing to repair on your way past.
