---
id: 0190-entity-in-a-parent-row
title: "0190 — an entity kept inside another entity's row has no spec form"
created: 2026-11-23
updated: 2026-11-23
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: L
importance: High
skills: [domain, code]
status: Open
blocked_by: []
related_to: [0143-entity-datastore, B3-overridable-types]
---

## Origin

A governed project reported it as I14. It was first seen on INSPIRE 0.19.0 with Factory v0.21.0
and is still there on INSPIRE 0.21.0 with Factory v0.23.0. It blocks a run.

The project's entity `findings::finding_call` holds one call per sample. Its ADR and
`stack.md` keep a finding's calls as Array columns in the finding's ClickHouse row, one element
per sample, so the calls have no table of their own. On 2026-11-18 Factory run 18 told the unit to
create the entity's own table. The unit saw that the spec contradicted the stack, and stopped.

## Description

### What happens today

- **Every entity gets a table of its own.** `inspire-code-nestjs` § Persistence builds one table
  per domain entity, from its `## Fields`, in its datastore
  (`inspire-domain/references/format-entity.md` § Datastore). The derived contract has no other
  shape for an entity.
- **An entity cannot say where its rows live inside another entity.** Its frontmatter has
  `population:` (who writes it) and `datastore:` (which database), and neither says that its
  rows live in another entity's row.
- **An analytical store does exactly that.** A columnar store such as ClickHouse often keeps the
  child records as arrays in the parent's row, one array per child field, instead of joining
  two tables. The decision sits in an ADR and in `stack.md`, which are prose that a unit never
  reads, so the unit builds a table the stack says must not exist.

### What this ticket asks for

The work starts with an ADR in `docs/adr/` that settles the shape. The direction:

- **An entity names the entity whose row holds it**, for example
  `embedded_in: findings.molecular_finding`. It keeps its own `## Fields`, invariants and
  `## Touched by`, so actions and screens still name it.
- **The contract carries it**, so the Factory builds the child's fields as columns of the
  parent's table, one array per field, and builds no table for the child. The field feeds the
  entity's fingerprint, and the parent's table claim covers the child's columns.
- **A validator checks it**: the parent exists, is not itself embedded, and lives in the same
  datastore, and the child declares no `datastore:` of its own.

### Open questions

- Is a child kept in its parent's row an entity at all? The alternative is to drop it and
  declare its fields on the parent as `list<T>` fields, one per child field. That needs no new
  form, but it loses the child's id, its invariants and the actions that touch it by name.
- How does an action that writes one child (`append`, `update`) read in the contract when the
  write is an update of the parent's row?
- Is the array per field the only shape, or does a datastore's `## Persistence` seed choose
  between arrays, a nested type and a JSON column?

## Acceptance criteria

- [ ] An ADR in `docs/adr/` decides the shape. If it decides the child is written as `list<T>`
      fields of its parent, `format-entity.md` says so, with an example, and the ticket closes
      Done with no new form.
- [ ] Otherwise `format-entity.md` defines the form, `_references/derived-contract.md` says what
      it derives to, a validator checks it with golden fixtures, and the stack skills' `## Persistence`
      seeds say how they build an embedded entity or why they refuse one.

## Notes

- Factory note: the deriver must read the new form and build the child's columns on the
  parent's table instead of a table of its own. The Factory ticket is filed in the Factory's
  tracker when the change here lands.
