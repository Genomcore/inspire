---
id: 0143-entity-datastore
title: "0143 — an entity cannot say which database it lives in"
created: 2026-11-16
updated: 2026-11-25
reporter: "@djessy.czaplicki"
closed_by: "@djessy.czaplicki"
closed_at: 2026-11-25
epic: follow-up
size: L
importance: High
skills: [domain, bootstrap, code]
status: Done
blocked_by: []
related_to: [FB2-kb-contradiction-check, B1-decisions-in-context, 090-reference-data-home]
---

## Origin

A governed project reported it as I13. It was first seen on INSPIRE 0.14.3 and is still there on
0.17.3. That project's `stack.md § Data` and an ADR put its high-volume genomic entities in
ClickHouse beside a PostgreSQL metadata database. Factory runs 7 to 13 built every one of them
as a PostgreSQL table, and about 30 prototype columns ended up with no data behind them. Since
Factory v0.18.0 a unit stops when its spec contradicts the stack, so the run now stops instead of
guessing. The stack's second database still never reaches the build.

## Description

### What happens today

- **An entity has no database field.** `inspire-domain/references/format-entity.md` defines only
  `population: internal | external`, which says whether an SDD action writes the entity, not
  where its rows live.
- **The stack has one persistence convention.** `## Persistence` is a seed on the backend
  framework skill (`_references/stack-skills.md`). The only binding profile is the single
  `layer: backend` one. `stack.md § Data` is prose that nothing reads as structure.
- **The contract can't carry the decision.** `_references/derived-contract.md` is built so a
  unit never has to read the KB: what a phase acts on is a declared fact in the contract, as
  `unit.population` is. An ADR is prose, and by design it never reaches a unit. The decision has
  nowhere structured to go, so the unit gets one database and nothing to refuse on.
- **Nothing checks it.** No validator compares an entity with the stack's data stores, and
  `FB2-kb-contradiction-check` can only report the contradiction in general terms.

Giving unit agents `stack.md` and the ADRs is not the fix. It brings back the guessing, breaks
the rule that the contract is enough, and moves every unit's fingerprint whenever any ADR
changes.

### What this ticket asks for

The work starts with an ADR in `docs/adr/` that settles the shape. The direction:

- **The stack declares its datastores** in `stack.md` frontmatter, each named and mapped to the
  stack id whose skill carries its `## Persistence` seed, for example
  `datastores: { metadata: postgres, analytics: clickhouse }`.
- **An entity names its datastore** in frontmatter (`datastore: analytics`). It is not called
  `store:`, because that word already means a face's store. With one datastore declared, the
  field is implied. With more than one, an entity without it is refused, following the
  stack-skills rule that an undeclared convention refuses the unit.
- **The contract carries it** as `unit.datastore`. The datastore's skill is served to the entity
  and to every action that touches it, and the field feeds the entity's fingerprint.
- **The validators check it:** a `datastore:` names a declared datastore, and a
  `references(...)` that crosses datastores is reported, since no foreign key spans two engines.
- **`inspire-domain` asks for it** when the stack declares more than one datastore, and
  `inspire-bootstrap` writes `datastores:` from `## Data`.

### Open questions

- Who owns the schema and the migrations of a `population: external` entity in a second
  datastore, when a pipeline loads its rows? If nobody does, the gap comes back one step later.
- Is a cross-datastore reference an error, a warning, or a typed reference with its own rule?
- Does a project with one datastore need `datastores:` at all, or does it stay implied by the
  backend profile's `## Persistence`?

### Until it ships

A stack skill with no `layer:` is already served to every unit whose stack names its id. A
project can add `clickhouse` to `profiles:` and a project skill with `stack: clickhouse` whose
`## Persistence` states the convention and lists the entities that live there. This reaches
the unit prompt today. The cost is that the list repeats what the entity specs should say.

## Acceptance criteria

- [ ] An ADR in `docs/adr/` records the shape: the `stack.md` field, the entity field, the
      refusal and the contract field.
- [ ] With two datastores declared, an entity without `datastore:`, or with one the stack does
      not declare, is reported by a validator, and fixtures cover both cases and a passing one.
- [ ] `derived-contract.md` specifies `unit.datastore` and which persistence skill a unit gets.
- [ ] `format-entity.md`, the `inspire-domain` interview and `inspire-bootstrap` cover the field.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- Related to `FB2-kb-contradiction-check`: once the decision is a field, this contradiction is
  found by a script, not by judgment.
- Related to `B1-decisions-in-context`: the digest puts the ADR in authoring sessions, but that
  helps the author, not the unit.
- Related to `090-reference-data-home`: both are about where an entity's rows come from.
- **Factory port, filed when this ships:** the deriver emits `unit.datastore` and refuses the
  same shapes. The persistence seed comes from the entity's datastore, not from the one backend
  profile, and "create its migration as usual" follows that datastore's migration rule.

## Closed 2026-11-25 — shipped

Shipped in Genomcore/inspire#127 (0.19.0), with the embedded case added in 0190 (0.23.0). Each
criterion, checked against `main`:

- [x] `docs/adr/adr-entity-datastore.md` records `datastores:` and `default_datastore:` in
      `stack.md` (D1), the entity's `datastore:` field (D2), the refusal (D3) and
      `unit.datastore` in the contract (D5).
- [x] `entity-datastore.sh` reports `datastore-missing`, `datastore-undeclared`,
      `datastore-default-undeclared` and `datastore-unserved`, with fixtures for each case and
      for passing ones (`plugin/base/bin/test/fixtures/entity-datastore/`).
- [x] `derived-contract.md` specifies `unit.datastore` and that an entity unit gets its
      datastore's stack skill.
- [x] `format-entity.md`, the `inspire-domain` entity interview and `inspire-bootstrap`'s stack
      interview and review cover the field.

Answers to the open questions, from the ADR:

- **Who owns the schema of a `population: external` entity in a second datastore?** The
  project does. `population: external` says only that no action writes the rows: the table is
  built from the entity's `## Fields` under its datastore's convention, and a pipeline only
  fills it (D4).
- **Is a cross-datastore reference an error?** No. `reference-crosses-datastore` is a warning,
  because no foreign key spans two engines and a real design often needs the link (D6).
- **Does a project with one datastore need `datastores:`?** No. Without it the project has one
  implied datastore whose convention is the backend profile's `## Persistence`, and nothing
  changes for an existing project (D1).

The Factory side shipped as its `0120-entity-datastore` (Genomcore/inspire-factory#196), and
genomics-suite has since run with entities in ClickHouse.
