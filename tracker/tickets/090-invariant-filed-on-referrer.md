---
id: 090-invariant-filed-on-referrer
title: "090 — a cross-entity invariant filed on the wrong side has no oracle"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: High
skills: [domain]
status: Open
blocked_by: []
related_to: [090-immutable-oracle-adr]
---

## Description

An entity's `## Invariants` section can hold a claim about rows that live in **another**
entity's table. The field run's `inv/I1` is the shape: *"every staff reference resolves to
a row here"*, declared on the referenced entity. Nothing on that entity can assert it. The
constraint that makes it true is a foreign key, and a foreign key is declared by the
**referrer** — where it derives as `references(...)`, a store claim the migration carries
for free.

Filed on the referent it becomes a keyed invariant with a `test` oracle and no venue: the
entity that declares it emits no write path for the other entity's rows, so the claim is
minted, uncited, and fires `GV-01` at the gate. The unit stalls on a property its own
schema cannot express and its own tests cannot reach.

This is not the same defect as `090-immutable-oracle-adr`, which was a claim whose oracle
class was wrong. Here the oracle class is right and the **artifact** is wrong: the claim
is filed on the entity it is *about* rather than on the entity that can enforce it. That
makes it a question for the domain skill — where a claim of this shape belongs, and
whether anything can tell the two sides apart mechanically.

## Acceptance criteria

- [ ] `inspire-domain`'s entity doctrine says where an invariant that spans two entities
      is filed, and why: on the side that declares the reference, so it derives as the
      store claim the schema already enforces.
- [ ] The interview prompts that produce `## Invariants` do not invite the referent-side
      spelling.
- [ ] Whether a rule can catch it is decided either way: a V2 invariant head whose
      argument is a field of *another* entity is either a checkable join (like the three
      `keyed-heads.md` § Coherence already own) or is named as not mechanically
      distinguishable, in one sentence, so nobody re-opens the question.
- [ ] Ratifying closes it: if the honest finding is that the existing prose already says
      this and the field run's author simply filed it on the wrong side, the fix is the
      interview prompt alone and this closes **Done**.

## Notes

Field evidence: the first `/inspire-emanate` run (`gs`, 2026-09-08), where `inv/I1` was
one of two invariant shapes that stalled an entity unit beside `immutable`. The other is
`090-reference-data-home`. Neither was solved by the `immutable` decision, which named
both as out of scope and pointed here.
