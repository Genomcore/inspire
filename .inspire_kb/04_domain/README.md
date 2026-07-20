# 04 · Domain

The **logical domain** of the system — its data model and its behavior, as a
precise, machine-checkable contract. Two kinds of object, deliberately coupled:

- **Entity documents** (`{module}.{entity}.md`) — the **data model**: what exists,
  its fields, its invariants. The logical schema.
- **Action descriptors** (`{module}.{entity}.{action}.md`) — the **behavior**:
  what can be done. The logical operation/API contract.

Actions declare which entities they *touch* (read / write / list / delete); an
entity's `Fields` table largely emerges from the actions that write it. The
validators (`entity-coherence`, `touched-entity-lifecycle`) enforce that coupling
— which is why the two live **together**, not in separate layers.

- **Skill:** `inspire-object` (define / show / update / refactor / delete /
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
| Data | entity document (fields + invariants) | DB schema — DDL, migrations, indexes, types |
| Behavior | action descriptor (contract) | API surface — HTTP routes, handlers, CLI/MCP bindings |

Keeping `04_domain` free of storage and transport details is deliberate: the
contract stays stable while the implementation is free to change.

The domain realises features ([`02_features`](../02_features)) and must respect
the decisions in [`01_adr`](../01_adr).
