---
id: 090-reference-data-home
title: "090 — reference rows have no home, so an invariant about them has no owner"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Mid
skills: [domain, code]
status: Open
blocked_by: []
related_to: [090-immutable-oracle-adr]
---

## Description

Some entities are **catalogs**: a fixed set of rows the product ships with, rather than
rows a user creates. The field run's `inv/I2` is one — *"the catalog ships with the
platform"* — and the loop has nowhere to put it.

Every phase is chartered against a unit's own contract. The contracter emits declarations,
the persistence model and its migration; the tester covers claims; the implementer turns
the suite green. **None of them is chartered to emit rows**, and the knowledge base has no
section that declares which rows an entity ships with. So the claim derives as a keyed
invariant with a `test` oracle, no phase produces the data it describes, no test can
assert it, and the unit stalls — with the invariant correctly stated and nothing wrong
with it.

Two halves, and the second only exists once the first is decided:

1. **Where the rows are declared.** A `## Seed rows` section on the entity, a bootstrap
   artifact, or a deliberate "the KB never holds data, only its shape" — with the
   consequence that such an invariant belongs in prose rather than as a keyed head.
2. **Who emits them.** A seed migration from the contracter, a phase of its own, or the
   operator by hand outside the loop. Whatever the answer, the derived claim's oracle
   follows it: rows carried by a migration are a store claim like any other, rows the loop
   never emits are not a claim at all.

## Acceptance criteria

- [ ] The first half is decided and written where a project reads it — the entity format
      doctrine, not `docs/adr/`.
- [ ] The second half names the emitter, or states that the loop does not emit reference
      rows and what an author writes instead.
- [ ] `keyed-heads.md` § Oracles and `derived-contract.md` follow the decision if it mints
      a claim; if it does not, the doctrine says so, so the shape stops reaching the gate.
- [ ] Ratifying closes it: "the knowledge base describes shape, never data" is a complete
      answer, provided the entity doctrine says it and the invariant spelling it displaces
      is named.

## Notes

Field evidence: the first `/inspire-emanate` run (`gs`, 2026-09-08). `inv/I2` stalled an
entity unit beside `immutable` and `inv/I1`. The other two were answered in the release
that surfaced them — `immutable` by the store-oracle decision, `inv/I1` by
`format-entity.md`'s rule that a cross-entity rule is declared where the reference is.
This one is filed instead because it is not answerable in a sitting: it needs a home for
something the knowledge base currently has no shape for, and the answer changes what an
entity document may contain.
