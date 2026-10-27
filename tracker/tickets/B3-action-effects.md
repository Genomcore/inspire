---
id: B3-action-effects
title: "B3 — An action with more than one effect"
created: 2026-10-27
updated: 2026-10-27
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: L
importance: High
skills: [domain, screens]
status: Open
blocked_by: []
related_to: [B3-entry-points]
---

## Origin

The INSPIRE maintainers held the third session of a design review on 2026-10-27 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** one action can cause several effects. For example, reserving a copy of a
book also lowers the count of available copies. How the spec models those effects needs
more debate, so this ticket keeps the options open.

## Description

### What happens today

**Domain side.** An action can already touch several entities. The action format allows
one `### [[entity]]` section per entity it touches ("mixed-entity actions"). What it has
no way to say is "when this happens, that other action runs".

**Screen side.** A dispatch's `On success` outcome takes exactly one form: navigate, a
state, or `refresh` of **one** data key. A reservation that changes both the reservation
and the availability counter can't refresh both.

### What this ticket asks for

1. **Now:** a dispatch outcome can refresh several data keys.
2. **Options to decide:**
   - (a) one action lists every effect itself, as it does today;
   - (b) **triggered actions**: a follow-up action declares that it runs when another
     action has happened. This is the open-closed shape: adding a reaction never edits
     the original action;
   - (c) both, with (b) through an entry point of the "trigger" kind (see
     `B3-entry-points`).
3. Whatever the choice, each triggered step has a precondition and a clear exit
   condition, so A updating B updating A always terminates.

### Open questions

- Is the trigger a precondition of the reacting action, or a separate artifact? The
  review leaned towards precondition, behaviour, postcondition. This depends on
  `B3-entry-points`.
- Can a validator find cycles between triggered actions, or is that review judgement?
- Concurrency (two people reserving the last copy) came up. It is about the backend's
  locking, not the spec. Confirm that.

## Acceptance criteria

- [ ] A dispatch outcome can refresh several data keys. `format-screen.md`,
      `screen-coherence.sh` and the derived contract accept it, with fixtures.
- [ ] One of options (a), (b) or (c) is chosen and recorded in an ADR or in this
      ticket's close note. Option (a) is a valid outcome and needs no format change
      beyond the multi-key refresh.
- [ ] If triggered actions are adopted, the format requires a precondition and an exit
      condition on each triggered step.
- [ ] The open questions have written answers in this ticket's close note.
