---
id: B3-action-verbs
title: "B3 — Each project models its own action verbs"
created: 2026-10-27
updated: 2026-10-27
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [domain, adr]
status: Open
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

- [ ] No shipped reference names a platform-specific verb, probe or ADR.
- [ ] The shipped references state the generic rules and a default verb set.
- [ ] The action interview reads the project's verb record when it exists and falls back
      to the defaults otherwise, and the record's home is documented.
- [ ] The open questions have written answers in this ticket's close note.
