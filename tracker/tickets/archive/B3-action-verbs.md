---
id: B3-action-verbs
title: "B3 — Each project models its own action verbs"
created: 2026-10-27
updated: 2026-10-29
reporter: "@dario.blasco"
closed_by: "@djessy.czaplicki"
closed_at: 2026-10-29
epic: roadmap
size: M
importance: Mid
skills: [domain, adr]
status: Done
blocked_by: []
related_to: [B1-config-replaces-bootstrap]
---

## Origin

The INSPIRE maintainers held the third session of a design review on 2026-10-27 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** the verb list is not part of INSPIRE. Each project models its own action
verbs in an ADR, or an equivalent project-level record. Verbs come from the
application's own domain and stay consistent within it. Each action still acts on a
single target object.

## Description

### What happens today

`inspire-domain/references/interview-prompts-action.md` says the verb choice "is not
free-form" and names its source of truth as `[[adr-plt-action-verb-conventions]]`, an
ADR that doesn't exist in a new project. Its mutation verbs (`create` · `edit` ·
`deploy` · `move` · `rollback` · `enable`/`disable` · `delete`) and its cross-cutting
probe (namespace/OU re-parenting, an Event Bus, "Audit subscribes") come from one
platform's conventions. Reserving, cancelling or picking up a book has no place in it.

That is product vocabulary in the generic runtime, which this repository's own rules
say must stay generic.

### What this ticket asks for

- INSPIRE keeps only the generic rules: one target object per action, and collection
  versus item reads. It ships a small default verb set.
- A project records its own verbs in an ADR or equivalent. The action interview reads
  that record when it exists and uses the defaults when it doesn't.
- The platform-specific verbs and probes come out of the shipped references.

### Open questions for the design

- An ADR or a config key? A key would tie this to the spec config of
  `B1-config-replaces-bootstrap`, like the semantic types and the product languages.
- Should a validator check action names against the project's verb list?

## Acceptance criteria

- [x] No shipped reference names a platform-specific verb, probe or ADR.
- [x] The shipped references state the generic rules and a default verb set.
- [x] The action interview reads the project's verb record when it exists and falls back
      to the defaults otherwise, and the record's home is documented.
- [x] The open questions have written answers in this ticket's close note.

## Resolution

A project's verbs live in one ADR with a fixed id, `adr-action-verbs`.
`/inspire-domain` reads it whenever it lands an action's verb, and uses the default set
`list` · `get` · `create` · `edit` · `delete` while it doesn't exist. A verb the
operator introduces is added to that ADR, through `/inspire-adr create action-verbs`
the first time, before the descriptor that uses it lands.

Every acceptance criterion holds:

- `interview-prompts-action.md` and `format-action.md` no longer name
  `adr-plt-action-verb-conventions`, `deploy`, `move`, `rollback`,
  `enable`/`disable`, namespace/OU re-parenting or the Event Bus probe. The
  pagination numbers (default 50, cap 200) went with them: pagination is the wire
  convention's, which already records it as a project policy.
- The generic rules stay, in both files: one target object per action (the entity the
  id names; the others are effects); a plural verb for a read that returns many,
  paginated; a singular verb for a read that returns one; and a change the domain
  names gets its own verb, never an overloaded `edit`. The per-field touch verbs are
  INSPIRE's and unchanged.
- The interview reads the ADR when it exists and falls back to the defaults. A new
  record probe adds a new verb to the ADR, and the cross-cutting probe applies only
  the rules that ADR attaches to a kind of verb. The home is documented as a named
  pattern in `/inspire-adr` (*The action-verbs ADR*), in `format-action.md`, and in
  the `01_adr` README.
- `_references/conventions/rest.md` keys its success table on the default set, and
  maps a project verb by what it does: creates a record → `201`, removes one →
  `204`, otherwise `200`.

The two open questions:

- **An ADR, not a config key.** Choosing a verb set is a decision with a rationale,
  which is what an ADR records, and an ADR needs nothing from
  `B1-config-replaces-bootstrap`, which is still open. If that ticket gives the spec
  config a home for project vocabulary, the record can move there then.
- **No validator checks action names against the list, for now.** The ADR is prose, so
  a validator would first need a machine-readable form of the list. Checking the verb
  is the interview's job (the record probe) and a review judgement. If the record ever
  becomes a config key, the check becomes cheap and is worth filing then.

## Notes

- `inspire-domain/examples/canonical-action-meta.md` still links
  `[[adr-plt-06-action-catalog]]`. It is an example of a meta action in a hypothetical
  `platform` module, and the link is that example project's ADR, not a rule the
  runtime imposes, so it stays.
- No Factory port: the change is interview and review guidance. Nothing the Factory's
  deriver reads changed.
