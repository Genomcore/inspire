# 04 · Domain

The **logical domain** of the system — its data model and its behavior, as a
precise, machine-checkable contract. Two kinds of object, deliberately coupled:

- **Entity documents** (`{module}.{entity}.md`) — the **data model**: what exists,
  its per-field constraints, its named invariants. The logical schema.
- **Action descriptors** (`{module}.{entity}.{action}.md`) — the **behavior**:
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
the keyed shape *is there at all* is a warning in 0.8, at every lifecycle, so a
vault upgraded to this release is not red on every artifact it already had;
`derive` refuses an old-shape artifact regardless, and those classes ramp in the
release after.

- **Skill:** `inspire-domain` (define / show / update / refactor / delete /
  promote / demote / review / source / graph).
- **Layout:**
  ```
  04_domain/
    {module}/
      {entity}/
        {module}.{entity}.md              # entity document (data model)
        {module}.{entity}.{action}.md     # action descriptor (behavior)
  ```
- **Validated** by the guardrail scripts in [`bin/`](../../bin) and enforced at
  git time by [`hooks/`](../../hooks). The spec root is configurable via the
  `SDD_SPEC_ROOT` environment variable (defaults to this folder).

## Logical here, physical in `/source`

This layer is **provider-agnostic and logical**. The *physical* realizations are
implementation and live in [`/source`](../../source), not here:

| Concern | Logical (here, `04_domain`) | Physical (`/source`) |
|---------|------------------------------|----------------------|
| Data | entity document (fields + constraints + named invariants) | DB schema — DDL, migrations, indexes, types |
| Behavior | action descriptor (contract: pre · steps · post · errors) | API surface — HTTP routes, handlers, CLI/MCP bindings |

Keeping `04_domain` free of storage and transport details is deliberate: the
contract stays stable while the implementation is free to change.

The domain realises features ([`03_features`](../03_features)) and must respect
the decisions in [`01_adr`](../01_adr).
