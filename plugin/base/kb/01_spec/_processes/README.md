# `_processes/` · work with nobody behind it

A **process** runs on a trigger instead of a person's request: a schedule, an
event, start-up, or another process. One file per process, `{process}.process.md`,
with `id: {scope}.{process}` — the scope is `global`, a module id or a face id.

A process states:

- `## Trigger` — what starts it;
- `## Requires` — the actions it calls, as links;
- `## Before` and `## After` — its pre-actions and post-actions, in order;
- `## Behaviour` — its steps, keyed `B{n}`;
- `## Affects` — the domain it changes.

Processes are scoped like ADRs: this directory holds the global ones, a module's or
a face's `_processes/` the scoped ones. A process without a trigger or without
actions is a finding.

**Skill:** `inspire-process`.
