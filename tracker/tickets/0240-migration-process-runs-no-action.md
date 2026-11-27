---
id: 0240-migration-process-runs-no-action
title: "0240 — a database migration cannot be a process, because a process must call an action"
created: 2026-11-27
updated: 2026-11-27
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: [adr, process]
status: Open
blocked_by: []
related_to: [090-reference-data-home]
---

## Origin

The INSPIRE maintainers held a support session with a new operator on 2026-11-27. The
operator asked whether the database migrations (PostgreSQL, ClickHouse) are infrastructure
or something the spec defines. The INSPIRE agent had told the operator that a process calls
actions and changes the domain only through them, and that a migration calls none.

**Decision:** running the database migrations is a process with a one-shot trigger. It runs
the DDL and calls no action: running the migration is the whole behaviour. If the skills do
not lead an operator to this, the skills change.

## Description

### What happens today

- `inspire-process/SKILL.md`: a process "calls actions, in order, and changes domain only
  through them". Its examples are a scheduled job, a token refresh and "the first population
  of the database". No example is a migration.
- `process-shape.sh` REQUIRES: "`## Requires` links at least one action. A process with no
  action does nothing", reported as "process runs no action".
- `adr-kb-structure` D7: "A process without a trigger or without actions is a finding."
- An action belongs to an entity (`{module}::{entity}::{action}`), and a migration has none,
  so a "run migrations" action has no home.
- Each entity unit writes its own migration file (`inspire-code-nestjs` § Persistence:
  "Migrations live in `src/migrations/`, one file per change"). No artifact says what runs
  them. For ClickHouse, `adr-entity-datastore` D3 (Proposed) puts the migration rule in the
  datastore's own stack skill.

So the agent quoted the rules correctly, and the operator kept the migrations out of the KB.

### What this ticket asks for

- `inspire-process` and `adr-kb-structure` D7: a process may run a system operation, such as
  the migrations, with no action. It changes the schema, not the domain, so rule 2 ("changes
  domain only through actions") stays.
- `process-shape.sh` accepts such a process and still reports a process that forgot its
  `## Requires`.
- `inspire-process` names "run the database migrations" as an example, with its trigger.

### Open questions

- How does a process say that it calls no action on purpose, so that a forgotten
  `## Requires` is still a finding?
- Which trigger: backend start-up, a deploy step, or an operator command?
- One process per datastore, or one that runs the migrations of every datastore?
- The entity units keep writing the migration files, and the process only runs them.
  Confirm.

## Acceptance criteria

- [ ] `inspire-process/SKILL.md` and `adr-kb-structure` D7 allow a process that runs a
      system operation with no action, and say how the process declares it.
- [ ] `process-shape.sh` accepts that process, reports a process with no action that does
      not declare it, and has a fixture for each case.
- [ ] `inspire-process` gives running the database migrations as an example, with its
      trigger.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- **Factory.** The INSPIRE Factory accepts a process with no `## Requires`: it refuses only
  a process with no trigger and a `## Before` or `## After` entry that links no action. This
  change needs no Factory work.
- `090-reference-data-home` asks where seed rows live, possibly in a seed migration. This
  ticket is about running the schema migrations, so it does not change that one.
