---
id: FB5-audit-events-kept
title: "FB5 — a backend emits an audit event on every write, and its log level drops it"
created: 2026-11-12
updated: 2026-11-12
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: S
importance: Mid
skills: [code]
status: Open
blocked_by: []
related_to: []
---

## Origin

The maintainers of INSPIRE and of the INSPIRE Factory held the fifth block of a follow-up review
of the Factory on 2026-11-11. The block covered errors and observability in the code the Factory
builds. This ticket records one of its decisions that needs work in this repository. The review's
working notes are not public, so this ticket states the decision in full.

**Decision:** the NestJS profile keeps its rule that every meaningful create, update and delete
emits an audit event, and those events become visible now: the generated backend keeps them and
does not discard them at an error-only log level. The concept of an audit log enters the
generated code now. When a shared logging library is available, only the profile changes: it
sends the same events through that library.

## Description

### What happens today

`inspire-code-nestjs/SKILL.md` (§ Forbidden patterns, "No silent domain mutations") and
`references/coding-standards.md` (§ Audit every meaningful domain mutation) require a typed audit
event from the service layer on every successful create, update and delete.
`references/testing.md` asserts that event in every write test. The emitter and the sink are "the
project's choice". Nothing in the profile says at which level the events are written, or that
the backend's logger configuration keeps them. A backend whose logger keeps only errors emits the
events and drops them, so they are stored nowhere.

### What this ticket asks for

- The profile says where audit events go and that the backend's default configuration keeps
  them: a log level that the configured logger keeps, or a channel that does not depend on the
  operational log level.
- The profile keeps audit events apart from operational logs, so a reader can filter them.
- A test or a check shows that, with the backend's default configuration, a create writes its
  audit event to the output.

### Open questions

- Where exactly are the events dropped: the logger levels in the generated `main.ts`, an
  environment default, or the test setup?
- A log level that the logger keeps, or a separate audit channel?
- Does the profile name a prefix for audit events now (for example `audit.` before the event
  name), or does that wait for the shared logging library?

## Acceptance criteria

- [ ] `inspire-code-nestjs` states where audit events go and that the default configuration
      keeps them.
- [ ] Audit events can be filtered apart from operational logs.
- [ ] With the backend's default configuration, a create writes its audit event to the output,
      and a test or a check shows it.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- When the shared logging library exists, the profile changes its emitter and keeps the events.
  That change is not part of this ticket.
