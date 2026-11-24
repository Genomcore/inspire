# ADR — An entity can live inside another entity's row

- **Status:** Proposed — 2026-11-23
- **Ticket:** `0190-entity-in-a-parent-row`
- **Builds on:** [adr-entity-datastore](adr-entity-datastore.md), whose rules place an entity's
  table and whose validator this one extends, and the derived contract's rule that a unit never
  reads the KB to learn a fact it acts on
  ([derived-contract.md](../../plugin/base/skills/_references/derived-contract.md)).
- **Scope:** An entity whose rows are kept inside the row of one other entity, and how that
  reaches the code that builds it. Not a general mapping from entities to tables, not views or
  materialized projections, and not a nested record inside one field (`record` and
  `list<record>` cover that in an action's inputs and outputs).

---

## Context

A governed project keeps its findings in ClickHouse. Each finding holds one call per sample,
and its ADR and `stack.md` keep those calls as Array columns of the finding's row, one array per
call field and one element per sample. The calls are an entity of their own,
`findings::finding_call`, with an id, fields, invariants and actions that read them. On
2026-11-18 a Factory run told the entity's unit to create its table, the unit saw that the stack
said otherwise, and the run stopped.

Every entity gets a table of its own today. `inspire-code-nestjs` § Persistence builds one per
domain entity, from its `## Fields`, in its datastore. An entity's frontmatter has
`population:`, which says who writes its rows, and `datastore:`, which says which database holds
them. Nothing says that its rows live inside another entity's row, and the ADR that says so is
prose that never reaches a unit.

## Decisions

### D1 — An entity names the entity whose row holds it

An entity's frontmatter gains `embedded_in: <entity id>`:

```yaml
---
id: findings.finding_call
module: findings
entity: finding_call
lifecycle: draft
population: external
embedded_in: findings.molecular_finding
---
```

Each row of the parent holds zero or more rows of the embedded entity. The embedded entity
keeps its whole document: `## Fields`, `## Invariants`, its per-field sections and
`## Touched by`. Actions and screens still name it, and its fields are still declared once, in
its own document, never copied onto the parent.

The parent names nothing: the embedded entity is the one that knows where it lives, as an
entity names its datastore and its references.

### D2 — An embedded entity lives in its parent's datastore

An embedded entity has no table, so it has no datastore of its own: it is in its parent's,
resolved under [adr-entity-datastore](adr-entity-datastore.md) D2. It may repeat that datastore
in `datastore:`, and naming any other one is an error. A stack with two or more datastores and
no default does not make the embedded entity name one.

Embedding is one level deep. A parent that is itself embedded is an error: the rows would live
inside an element of another entity's array, which no datastore's convention describes.

### D3 — The parent's datastore lays out the embedded rows

How the embedded rows sit in the parent's row is a convention of the parent's datastore, so it
belongs to the `## Persistence` section of the stack skill that serves it, like every other
table convention. A columnar store keeps one array per field, one element per embedded row. A
relational store may keep one JSON column holding an array of objects.

The shipped `inspire-code-nestjs` seed does the second: one `jsonb` column on the parent's
table, named with the embedded entity's plural, holding an array of objects keyed by its field
names. A project's own database skill states its own layout.

### D4 — Only constraints that hold per element

A field constraint is a store claim the table enforces. Inside an array, `nonnull` and
`default(…)` still describe each element, and `references(…)` is kept by the application,
since no foreign key reaches an element of an array.

`unique` and `immutable` on an embedded field are errors: no store indexes an element of an
array or guards one element against an update of the row that holds it. A rule of that kind is
written as an invariant, which is tested. `id` is exempt, as it is from the unique-field rules in
`keyed-heads.md`: an embedded row still carries an id, generated per element.

### D5 — The derived contract carries it

- **`unit.embedded_in`** is the parent's id, on the embedded entity alone. It is absent on every
  other entity, so a project that embeds nothing derives byte-identical contracts and keeps
  every fingerprint.
- **`unit.datastore`** of an embedded entity is its parent's, under the same rule as for any
  entity: absent when `stack.md` declares no `datastores:`.
- **`requires`** gains the parent, with `ordering: true`: the parent's table must exist before
  the embedded entity's columns are added to it.
- **One more claim**, `{module}.{entity}/embedded` (oracle `store`): the embedded rows live in
  the parent's row, laid out under the parent's datastore's `## Persistence`, and the embedded
  entity has no table. Its fingerprint covers the parent's id and the stack id the parent's
  datastore maps to, so moving the entity to another parent, or the parent to another
  database, makes it stale.
- **No datastore claim.** An embedded entity makes no `{module}.{entity}/datastore` claim, even
  outside the default: that claim says its table exists in a datastore, and it has none.
- **The parent's contract does not change.** Embedding an entity adds no claim to the parent,
  so the parent is not rebuilt; the embedded entity's unit adds its columns to the parent's
  table in a migration of its own.
- **An action's `entities`** objects gain `embedded_in`, so an action that reads or writes an
  embedded entity knows it reads or writes the parent's row, without opening either document.
- **Refusal.** A new class, `DR-D4`, refuses an embedded entity whose parent has no document, is
  itself embedded or is the entity itself, whose `datastore:` names a datastore other than its
  parent's, or whose field other than `id` carries `unique` or `immutable`. Its remedy is
  `/inspire-domain update {id}`.

### D6 — The datastore validator checks it

`entity-datastore.sh` reports, as errors at every lifecycle:

- `embedded-parent-missing`: `embedded_in:` names no entity document, or the entity itself.
- `embedded-chain`: the parent is itself embedded.
- `embedded-datastore`: the entity's `datastore:` names a datastore other than its parent's.
- `embedded-constraint`: a field other than `id` carries `unique` or `immutable`.

And as a warning, `embedded-reference`: a `references(…)` into an embedded entity, or out of
one. No foreign key reaches an element of an array, so the reference holds only as far as the
application keeps it.

The rule's datastore checks treat an embedded entity as living in its parent's datastore, so
`datastore-missing` never asks it to name one.

### D7 — The authoring skills say it

`format-entity.md` defines the field beside `population:` and `datastore:`, and `inspire-domain`
writes it when an entity's rows are kept in another entity's row, which an ADR or the stack
usually says.

## Consequences

- The reported project marks `findings::finding_call` with `embedded_in:`, and its unit adds the
  calls' columns to the finding's table instead of creating a table the stack forbids.
- Existing projects need no migration: no hop, no layout change, and contracts derive unchanged
  until an entity names `embedded_in:`. Marking an entity that is already built adds its
  `embedded` claim and retires its datastore claim, if it had one, so that entity alone is
  rebuilt: its migration moves the rows into the parent's columns and drops its table.
- **The INSPIRE Factory needs matching work, and must ship first.** Factory v0.24.0 and earlier
  read entity frontmatter key by key and ignore any key they do not know, so with this field alone
  they would still build the embedded entity's table. Factory 0.25.0 is the first release that
  derives it. Its deriver reads `embedded_in`, emits
  `unit.embedded_in`, the parent edge, the `embedded` claim and `DR-D4`, drops the datastore
  claim for an embedded entity, adds `embedded_in` to an action's entities, and tells the
  entity's unit to add columns to the parent's table instead of creating one.

## Alternatives considered

- **Drop the embedded entity and declare its fields on the parent as `list<T>` fields**, one per
  embedded field. It needs no new form, but the embedded rows lose their id and their
  invariants, the arrays are no longer tied to each other, and actions can no longer name the
  entity they touch.
- **Let the parent list what it embeds.** Rejected: an entity's document would describe columns
  another document declares, and adding an embedded entity would move the parent's fingerprint
  and rebuild it.
- **Embed through `population: external`.** Rejected for the reason adr-entity-datastore gives:
  who writes the rows and where they live are independent facts.
- **Leave the layout to the unit.** Rejected: an undeclared convention refuses the unit
  (`stack-skills.md` § *Seeds*), and a unit choosing between arrays and a JSON column is the
  guess the reported run would have made.
