# ADR — An entity names the datastore it lives in

- **Status:** Proposed — 2026-11-16
- **Ticket:** `0143-entity-datastore`
- **Builds on:** the stack-skills rule that an undeclared convention refuses the unit
  ([stack-skills.md](../../plugin/base/skills/_references/stack-skills.md) § *Seeds*), and the
  derived contract's rule that a unit never reads the KB to learn a fact it acts on
  ([derived-contract.md](../../plugin/base/skills/_references/derived-contract.md)).
- **Scope:** Where an entity's rows are stored when a project has more than one database, and
  how that reaches the code that builds the entity. Not how data moves between databases, not
  query routing across them, and not anything about a datastore the spec never names.

---

## Context

A governed project keeps its metadata in PostgreSQL and its genomic variants, calls and findings
in ClickHouse. Its `stack.md § Data` and one of its ADRs say so. Factory runs 7 to 13 built all
of those entities as PostgreSQL tables, and about 30 prototype columns ended up with no data
behind them. Since Factory v0.18.0 a unit whose spec contradicts the stack stops instead, so the
run stops; the decision still never reaches the build.

Nothing in INSPIRE can carry it there:

- **An entity has no database field.** Its frontmatter carries `population: internal | external`,
  which says whether an SDD action writes its rows, never where those rows live.
- **The stack has one persistence convention.** `## Persistence` is a seed on the backend
  framework skill (`stack-skills.md`), and `stack.md § Data` is prose that nothing reads.
- **The contract is self-sufficient by design.** A unit reads its derived contract and its stack
  skills, never `stack.md` or an ADR, so that a fact a phase acts on is declared, carried and
  fingerprinted. An ADR's decision is prose, and prose cannot reach a unit.

Handing the unit agent `stack.md` and the ADRs would bring the guessing back: the agent would
decide which entities "sound analytical" and build what it concluded. It would also move every
unit's fingerprint whenever any ADR changed. The decision needs a field.

## Decisions

### D1 — `stack.md` declares its datastores, each served by one stack id

`stack.md`'s frontmatter gains an optional map from a datastore id to the stack id that serves it:

```yaml
profiles: [react, nestjs, postgres, clickhouse]
datastores:
  metadata: postgres
  analytics: clickhouse
default_datastore: metadata
```

A datastore id is a project's own name for one database (`metadata`, `analytics`). Each value is
a stack id that `profiles:` also lists, so its stack skill resolves the way every stack skill
does: the skill whose frontmatter `stack:` is that id.

`default_datastore:` is optional and names one declared datastore. An entity that names no
datastore lives in the default one (D2). A project whose entities mostly share one database
declares it as the default and marks only the exceptions. With a single entry in
`datastores:`, that entry is the default whether or not `default_datastore:` names it.

Without `datastores:`, the project has one implied datastore whose convention is the backend
profile's `## Persistence`, exactly as today. A project with one database declares nothing, and
an existing project changes nothing.

### D2 — An entity names its datastore unless the stack declares a default

An entity's frontmatter gains `datastore: <id>`:

```yaml
---
id: genomics.variant
module: genomics
entity: variant
lifecycle: draft
population: external
datastore: analytics
---
```

| `datastores:` in `stack.md` | entity without `datastore:` | entity with `datastore:` |
|---|---|---|
| absent | the implied datastore | error: nothing declares it |
| one entry | that entry | that entry, or an error if it names another |
| two or more, with `default_datastore:` | the default | that entry, or an error if undeclared |
| two or more, no `default_datastore:` | error: the entity must choose | that entry, or an error if undeclared |

The field is `datastore`, not `store`: `store` already names a face's application state
(`{face}.store.md`).

The default is the project's decision, written in `stack.md`, never INSPIRE's. Without one, a
missing choice is a refusal: picking the first datastore, or the backend profile's, is the guess
the reported runs made.

### D3 — The datastore's stack skill carries the entity's persistence convention

The convention an entity's table follows is the `## Persistence` section of the stack skill its
datastore names (`stack: clickhouse`): the engine, the table and column naming, the keys and the
migration rule. For an entity in the implied datastore it stays the backend profile's
`## Persistence`. A datastore whose skill is missing, or has no `## Persistence`, refuses every
entity in it, since that is an undeclared convention (`stack-skills.md` § *Seeds*).

INSPIRE ships no ClickHouse skill and no skill for any second engine. A project writes its own,
as it already may for any database (`stack-skills.md`).

### D4 — `population: external` does not change who owns the table

`population: external` says no SDD action writes the entity's rows. It does not say the table
exists elsewhere. The project creates the table from the entity's `## Fields`, under its
datastore's convention, as for any other entity; a pipeline outside the spec only fills it. The
entity document stays the one place that says what the columns are.

### D5 — The derived contract carries the datastore

- **`unit.datastore`** is an entity's datastore id, resolved under D2: the default when the
  entity names none. It is absent when the stack declares no `datastores:`, so a project that
  declares none derives byte-identical contracts and every fingerprint stays where it was.
- **An action's `entities`** objects gain `datastore`, so an action that reads or writes an
  entity knows which database it queries without reading the entity's document.
- **A datastore claim.** An entity with a `unit.datastore` makes one more claim,
  `{module}.{entity}/datastore` (oracle `store`), whose fingerprint covers the datastore id and
  the stack id it maps to. Moving an entity to another datastore makes that claim stale and
  rebuilds its table where it now belongs, and so does changing the `default_datastore:` an
  entity relies on. A project without `datastores:` makes no such claim, so its claims and
  fingerprints stay as they were.
- **Refusal.** A new class, `DR-D3`, refuses an entity whose datastore is missing or undeclared
  under D2, resolves to a `default_datastore:` that `datastores:` does not declare, or names a
  datastore D3 cannot serve. Its remedy is `/inspire-domain update {id}` for
  the entity's field and `/inspire-bootstrap` for the stack.

### D6 — A validator checks the field; a reference across datastores is a warning

A new rule, `entity-datastore.sh`, in `review.sh`'s default list, reports as errors at every
lifecycle:

- `datastore-missing` (error): the stack declares two or more datastores and no default, and an
  entity names none.
- `datastore-default-undeclared` (error): `default_datastore:` names a datastore `datastores:`
  does not declare, or is set without `datastores:`.
- `datastore-undeclared` (error): an entity names a datastore the stack does not declare, or the
  stack declares none.
- `datastore-unserved` (error): a `datastores:` value is not in `profiles:`, or no stack skill
  declares it.

And as a warning:

- `reference-crosses-datastore`: a field's `references(…)` names an entity in another datastore.
  No foreign key spans two engines, so the reference holds only as far as the application keeps
  it. The warning says so; it does not block, because a real design often needs that link.

### D7 — The authoring skills ask for it

- `inspire-bootstrap` writes `datastores:` from `## Data` when the stack names more than one
  database, asks which stack id serves each, and asks whether one of them is the default.
- `inspire-domain` asks for the datastore when it creates or updates an entity in a stack that
  declares two or more. With a default declared, it offers the default and writes `datastore:`
  only when the entity lives elsewhere.
- `format-entity.md` defines the field beside `population:`.

## Consequences

- An ADR that puts an entity in a second database becomes a field the validator and the deriver
  check. The contradiction `FB2-kb-contradiction-check` could only report in general terms is now
  found by a script.
- Existing projects need no migration: no hop, no layout change, and contracts derive unchanged
  until a project declares `datastores:`.
- A project with a second database must write a stack skill for it with a `## Persistence`
  section before its entities can be built there.
- **The INSPIRE Factory needs matching work**, filed in its tracker when this ships: its deriver
  reads `datastore`, emits `unit.datastore`, the datastore claim and `DR-D3`, adds `datastore` to an
  action's entities, and serves the datastore's skill. The contracter's "create its migration as usual" follows the
  datastore's migration rule.

## Alternatives considered

- **Give unit agents `stack.md` and the ADRs.** Rejected: prose brings the guess back, and the
  contract stops being enough. See *Context*.
- **One datastore per module.** Rejected: the reported project keeps metadata and genomic data in
  the same module, and a module is a slice of the domain, not of the infrastructure.
- **Infer the datastore from `population: external`.** Rejected: many externally populated
  entities are catalogs in the main database, and the two facts are independent.
- **Make every project declare `datastores:`.** Rejected: it forces a change on every project for
  a need few have.
