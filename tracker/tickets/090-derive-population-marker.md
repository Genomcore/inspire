---
id: 090-derive-population-marker
title: "090 — derive: `population: external` never reaches the derived contract"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: []
status: Open
blocked_by: []
related_to: [090-immutable-oracle-adr]
---

## Description

An entity document's frontmatter may carry `population: external`, which
`format-entity.md` calls a **structural claim**: no SDD-layer action writes this entity,
and `entity-coherence.sh`'s `write-on-external` already enforces it. The marker never
reaches `inspire.derived-contract/1`. There is no `population` key in the derived unit —
the contract's `.unit` carries `entity, id, kind, lifecycle, module, path` and nothing
else — and no reference to the word anywhere under `bin/lib/derive-*.sh` or in
`derived-contract.md`.

So the one fact that tells a contracter *"declare no method awaiting a body, nothing
writes this"* and tells a tester *"there is no write path to exercise"* is decided by
reading the knowledge base, which the personas are forbidden to do. In the first field
run the `workspace.role` contracter inferred it from the invariant prose (`I2 — no action
writes it`) and emitted no stub, correctly, by luck of a well-written invariant. The
quality overseer then had to re-derive the same fact from the entity file to rule on the
unit's stall.

## Acceptance criteria

- [ ] `inspire.derived-contract/1` gains `unit.population` for `kind: entity`, carrying
      the frontmatter value or the format's default. Additive: a consumer reading
      `.unit.kind` or `.unit.id` is unaffected, and `derived-contract.md` documents the key
      beside the others.
- [ ] `emanate-plan.sh` carries it into `units[]`, so a spawn brief can be built from the
      plan JSON alone, as § persona already requires for profiles and wire conventions.
- [ ] `contracter.md` § Emission and `tester.md` each carry one sentence on what the
      marker changes for them — no compile stub for an entity nothing writes; no
      write-path venue to look for.
- [ ] Golden fixtures: `canonical-entity` asserts the default; a new
      `clean-entity-external` asserts `external`; `emanate-plan` fixtures carry the key.

## Notes

Whether `population: external` should also change the **oracle** of `immutable` is the
ADR's question (`090-immutable-oracle-adr`), not this ticket's. This one only makes the
marker visible to the tool chain; what the tool chain does with it is decided there.
