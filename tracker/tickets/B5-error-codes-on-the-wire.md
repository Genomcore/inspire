---
id: B5-error-codes-on-the-wire
title: "B5 — an API answers with a status, not with the error the spec declared"
created: 2026-10-30
updated: 2026-10-30
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [domain, code]
status: Open
blocked_by: []
related_to: [B3-ui-text-keys, B4-one-home-per-value]
---

## Origin

The INSPIRE maintainers held the fifth and last session of a design review on 2026-10-29
while preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** an API returns the error code that the spec declares, as well as the HTTP
status. A client can then act on the reason, for example tell two different `409`s
apart, and show a translated message. The codes are shared with the front end through
one common library. In a monorepo, that is a shared package.

## Description

### What happens today

Every action's `## Errors` declares a code, such as `email_exists`, with an
operator-facing message (`inspire-domain/references/format-action.md`). The REST wire
convention (`_references/conventions/rest.md`) maps each logical error *class* to a
status, and its default error body is `problem+json`. Nothing says the declared code
travels in that body. Only one row, the expired credential, asks for "a distinct code in
the error body". The front-end stack skills (`inspire-code-react`,
`inspire-code-angular`) have no rule for reading errors, and no artifact lists all of a
product's error codes.

### What this ticket asks for

- The REST and GraphQL conventions require the declared code in every error body. For
  `problem+json`, that is an extension member such as `code`. The always-present test
  cases assert it.
- Codes are unique within a product, or qualified by module, and the domain review
  checks this.
- The front-end stack skills branch on the code, never on the status alone, and look up
  the user's message by code.
- The set of all declared codes is generated from the KB into a package that the back end
  and the front end both import. In a monorepo it is a shared package. For separate
  repositories, the design says how they get it: a published package, or the OpenAPI
  document.

### Open questions

- Is the shared list generated from the KB on each build, or written by hand and checked
  against the KB?
- Do the front end's translated messages follow `B3-ui-text-keys`, keyed by the error
  code?
- Which module owns a code that several actions raise?

## Acceptance criteria

- [ ] The REST and GraphQL conventions require the declared error code in the error
      body, and their always-present cases assert it.
- [ ] The domain review reports two actions declaring the same code with different
      meanings.
- [ ] The front-end stack skills state how a client reads an error: by code first.
- [ ] A project can get the list of every declared code in a form its back end and front
      end both import, and the ticket documents how for a monorepo and for separate
      repositories.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- Related to `B3-ui-text-keys`: an error's user-facing message would be one more keyed
  text, with the error code as its key.
- Related to `B4-one-home-per-value`: the action's `## Errors` stays the one home of a
  code. The shared package is generated from it, so it is not a second copy to keep in
  sync.
- Under the INSPIRE Factory's control-plane design, the wire conventions move into
  Config, which is where the error-body rule would then live.
- **Factory port, filed when this ships:** the Factory's deriver passes each declared
  code into the unit's contract, so emanated tests assert the error body.
