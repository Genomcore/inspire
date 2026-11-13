---
id: FB5-exists-precondition-error
title: "FB5 — an `exists` precondition without a declared error lets the agent invent the code"
created: 2026-11-12
updated: 2026-11-12
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: S
importance: Mid
skills: [domain]
status: Open
blocked_by: []
related_to: [B5-error-codes-on-the-wire]
---

## Origin

The maintainers of INSPIRE and of the INSPIRE Factory held the fifth block of a follow-up review
of the Factory on 2026-11-11. The block covered errors and observability in the code the Factory
builds. This ticket records one of its decisions that needs work in this repository. The review's
working notes are not public, so this ticket states the decision in full.

**Decision:** a spec check requires every precondition whose head is
`exists({module}.{entity})` to have an `## Errors` entry with the same head. The missing error is
found in the spec, before the Factory runs, so the Factory does not spend time on it and no agent
invents an error code.

## Description

### What happens today

`_references/keyed-heads.md` defines `exists(...)` as a precondition head (V3) and lets an error
carry the same head (V5). `inspire-domain/examples/canonical-action-meta.md` pairs
`P1 — exists(platform.action)` with `action_not_found — exists(platform.action)`, but only as an
example. `bin/head-referents.sh` already makes this join for uniqueness: `OS-X1` fails an action
that writes a `unique` field and declares no `unique(...)` error. No check makes it for `exists`.
The Factory's deriver mirrors `OS-X1` and has no `exists` join either. An action with an unpaired
`exists` reaches the unit agent, which makes up a code.

### What this ticket asks for

- `head-referents.sh` gets a new join, `OS-X5`: a `P{n}` with head `exists({module}.{entity})`
  requires an `## Errors` entry with the head `exists({module}.{entity})`. It blocks, like
  `OS-X1`.
- Fixtures for a paired and an unpaired `exists`.
- `keyed-heads.md` states the rule, and the existence probe in
  `inspire-domain/references/interview-prompts-action.md` asks for the error.

### Open questions

- Do `absent(...)`, `state(...)` and `actor(...)` need the same join? `absent` often restates a
  `unique` that `OS-X1` already covers.
- One error per `exists` precondition, or may one error cover two preconditions on the same
  entity?

## Acceptance criteria

- [ ] `head-referents.sh` reports `OS-X5` for a `P{n}` with head `exists({module}.{entity})` and
      no `## Errors` entry with that head, and passes when the entry exists.
- [ ] `keyed-heads.md` and the existence probe state the rule.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- Related to `B5-error-codes-on-the-wire`: that ticket sends the declared code to the client, and
  this check makes sure there is one to send.
- **Factory port, filed when this ships:** the Factory's deriver refuses the same shape, with the
  same message.
