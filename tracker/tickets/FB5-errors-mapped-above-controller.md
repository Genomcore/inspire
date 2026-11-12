---
id: FB5-errors-mapped-above-controller
title: "FB5 — an error raised before the controller reaches the client as a generic error"
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
related_to: [B5-error-codes-on-the-wire]
---

## Origin

The maintainers of INSPIRE and of the INSPIRE Factory held the fifth block of a follow-up review
of the Factory on 2026-11-11. The block covered errors and observability in the code the Factory
builds. This ticket records one of its decisions that needs work in this repository. The review's
working notes are not public, so this ticket states the decision in full.

**Decision:** the NestJS profile maps domain errors to HTTP in a layer above the controller, so
an error raised before the handler runs (for example in authentication) reaches the client with
its declared status, not a generic error. A domain error that the handler's service raises, such
as a row that is not found, still maps to its status (a `404`). The fix is in the profile.

## Description

### What happens today

`inspire-code-nestjs/SKILL.md` (§ Layering) forbids a controller to catch or translate errors and
sends domain errors to HTTP through an exception filter "registered on the controller or the
app". When the agent registers the filter on the controller, an error raised before the request
reaches that controller (in middleware, for example) does not pass through it. NestJS then
answers with its generic error. The profile has no test case for an error raised before the
handler.

### What this ticket asks for

- The profile registers the domain-error filter once, for the whole app, and no longer allows a
  filter on a controller.
- The filter maps every domain error, wherever it is raised, to its declared status.
- An e2e case asserts that an error raised before the handler (an authentication failure) returns
  its declared status and body, not a generic `500`.

### Open questions

- Does a controller keep a filter of its own for errors that only it raises, or does everything
  go through the app filter?
- The other stack profiles are front ends and mobile. Does a future backend profile inherit the
  rule from a shared reference, or restate it?

## Acceptance criteria

- [ ] `inspire-code-nestjs` registers the domain-error filter for the whole app.
- [ ] Its testing reference has an e2e case for an error raised before the handler, asserting the
      declared status and body.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- Related to `B5-error-codes-on-the-wire`: that ticket says what the error body carries. This
  ticket says which layer writes it, so that every error carries it.
