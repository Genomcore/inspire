---
id: 0200-screen-tests-miss-the-request-shape
title: "0200 — a screen's tests pass while the API refuses every request it sends"
created: 2026-11-20
updated: 2026-11-20
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [code]
status: Open
blocked_by: []
related_to: [B5-react-skill-from-the-team]
---

## Description

Early adopters met this on genomics-suite, ticket GSTKT-78 (INSPIRE 0.20.0, Factory 0.22.1,
2026-11-19). It hid a broken screen and ended in code changed by hand.

### What happened

The spec removed `org_id` from the inputs of `projects::project::create`. The screen
`studio.project-create` kept sending it, and the API answered every submit with `400`. The
screen's client, hook, error map and tests were all built from the old spec. The tests mock the
API, so they stayed green, and nothing in the screen's checks saw the `400`. The operator found
it, and removed `org_id` by hand in the client, the hook, the error map and the tests
(genomics-suite commit `7996d591`).

### What happens today

`inspire-code-react` requires every mock to live in the centralized mock layer
(`SKILL.md` § tests, `references/testing.md` § Mock architecture). Nothing ties a mock, or the
request type of a screen's API client, to the contract of the action it calls. A screen's test
proves that the screen sends what its own client type says, never that the API accepts it.

### What this ticket asks for

- A screen's request and response types come from the action's contract, not from a type the
  screen declares itself, so a removed or renamed input breaks the screen's typecheck.
- The centralized API mock checks each request against that contract, and fails the test on an
  input the action does not take or a required input that is missing.
- The rule is written in `inspire-code-react` and holds for the other front-end stack skills that
  mock the API (`inspire-code-angular`, `inspire-code-ios`, `inspire-code-android`), or each one
  says why it does not apply.

### Open questions

- Where do the shared types come from: the NestJS OpenAPI document, a types package the API
  exports, or the Factory's derived contract?
- Is an end-to-end test per dispatched action, against the real API, the better check?

## Acceptance criteria

- [ ] In a fixture project, removing an input from an action makes the screen that sends it fail
      its typecheck or its tests.
- [ ] `inspire-code-react` states the rule, and the other front-end skills state it or say why
      not.

## Notes

- Factory note: the planner did not rebuild the screen when the action's inputs changed. That is
  Factory work, filed in the Factory's tracker. This ticket is why the screen's own checks did
  not catch it.
