# `_modules/` · the domain, one module at a time

A **module** is a slice of the product: its use cases, its entities and its
actions, and the decisions that bind only it. One directory per module, and every
file in it carries its typed extension:

```
_modules/
  {module}/
    {module}.module.md                # the hub: overview, relationships, links
    _adr/{slug}.adr.md                # decisions that bind this module only
    _features/{use-case}.feature.md   # one file per use case
    _domain/
      {entity}/
        {entity}.entity.md            # the data model
        {entity}.{action}.action.md   # the behaviour
    _processes/{process}.process.md   # processes scoped to this module
```

- **Skills:** `inspire-module` (the hub: create / review / update / scan / delete),
  `inspire-feature` (use cases), `inspire-domain` (entities and actions),
  `inspire-adr` (decisions), `inspire-process` (processes).
- **New hub:** `.claude/skills/inspire-module/templates/module.template.md` →
  `{module}/{module}.module.md`.
- The hub is the one place that sees the whole module. Screens are not here: they
  belong to the face that shows them (`_faces/`), and they link the actions they use.

## Features

Product intent — **one file per use case**: what the system does and for whom.

**Four sections of a use case carry keyed entries**: `## Preconditions` (`P{n}`),
`## Main flow` (`B{n}`), `## Postconditions` (`Q{n}`) and the `AC-{n}`
acceptance criteria. Keys are write-once and never renumbered — deleting a step
leaves a gap, which is the contract working, and anything citing a step keeps
citing the same one. Most use-case entries are legitimately prose: a use case
describes what from the user's perspective, and the optional machine-readable
heads exist for the few places one fits exactly. The shared grammar lives in
`.claude/skills/_references/keyed-heads.md`. Use-case files carry no
`lifecycle:`, so every finding in this layer is a **warning** — including the
one that says a `## Main flow` step predates keyed steps.

## Domain

The **logical domain** of the system — its data model and its behavior, as a
precise, machine-checkable contract. Two kinds of object, deliberately coupled:

- **Entity documents** (`{entity}.entity.md`) — the **data model**: what exists,
  its per-field constraints, its named invariants. The logical schema.
- **Action descriptors** (`{entity}.{action}.action.md`) — the **behavior**:
  what can be done, under what preconditions, leaving what true afterwards. The
  logical operation/API contract.

Actions declare which entities they *touch* (read / write / list / delete); an
entity's `Fields` table largely emerges from the actions that write it. The
validators (`entity-coherence`, `touched-entity-lifecycle`) enforce that coupling
— which is why the two live **together**, not in separate layers.

**Every named claim in this layer is keyed.** An entity's invariants are `I{n}`
entries; a descriptor's steps are `B{n}`, its preconditions `P{n}`, its
postconditions `Q{n}`; a field's or an input's constraints sit on a
`Constraints:` line under its own H3, in a closed vocabulary. Keys are
write-once and never renumbered, which is what lets a change to one claim leave
every other claim untouched. The grammar, the vocabularies and what a strict
reader refuses are one contract, in
`.claude/skills/_references/keyed-heads.md`; the validators
`keys-present`, `constraints-mechanics` and `head-referents` check it. What a
keyed entry *says* blocks from `accepted` onward — a word outside the
vocabulary, a wrong arity, a duplicate key, an unresolvable referent. Whether
the keyed shape *is there at all* is a warning in 0.9, at every lifecycle, so a
vault upgraded to this release is not red on every artifact it already had;
`derive` refuses an old-shape artifact regardless, and those classes ramp in the
release after.

**An invariant's subject is the entity it is filed on.** An entity states
structure — what a row may hold, which tuples may coexist, what never changes
once written. Behaviour is the action's, in its preconditions, postconditions
and errors; a rule about another entity belongs on that entity, or on the
referrer that declares the reference; and a restatement of a `population:`
marker, of a `references(…)`, or of an action's `Q` head is not an invariant.
A rule filed on the wrong entity is enforced by nothing there, and the claim it
mints can only be asserted as an absence. The authoring rule and its worked
cases are in `inspire-domain`'s `references/format-entity.md`; `PR-26` is the
plan-time net, and is a heuristic that never blocks.

- **Validated** by the guardrail scripts in `.inspire/bin/` and enforced at git
  time by the hooks. The spec root is configurable via the `SDD_SPEC_ROOT`
  environment variable (defaults to `inspire_kb/01_spec`).

## Logical here, physical in `/source`

This layer is **provider-agnostic and logical**. The *physical* realizations are
implementation and live in `/source`, not here:

| Concern | Logical (here, `_domain/`) | Physical (`/source`) |
|---------|------------------------------|----------------------|
| Data | entity document (fields + constraints + named invariants) | DB schema — DDL, migrations, indexes, types |
| Behavior | action descriptor (contract: pre · steps · post · errors) | API surface — HTTP routes, handlers, CLI/MCP bindings |

Keeping the domain free of storage and transport details is deliberate: the
contract stays stable while the implementation is free to change.

The domain realises the module's features and must respect the decisions in
`_adr/`, the module's own and the global ones.
