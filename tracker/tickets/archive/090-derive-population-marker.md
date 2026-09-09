---
id: 090-derive-population-marker
title: "090 — derive: `population: external` never reaches the derived contract"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-09-09
epic: follow-up
size: S
importance: Mid
skills: [code, domain]
status: Done
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

- [x] `inspire.derived-contract/1` gains `unit.population` for `kind: entity`, carrying
      the frontmatter value or the format's default. Additive: a consumer reading
      `.unit.kind` or `.unit.id` is unaffected, and `derived-contract.md` documents the key
      beside the others.
- [x] `emanate-plan.sh` carries it into `units[]`, so a spawn brief can be built from the
      plan JSON alone, as § persona already requires for profiles and wire conventions.
- [x] `contracter.md` § Emission and `tester.md` each carry one sentence on what the
      marker changes for them — no compile stub for an entity nothing writes; no
      write-path venue to look for.
- [x] Golden fixtures: `canonical-entity` asserts the default; a new
      `clean-entity-external` asserts `external`; `emanate-plan` fixtures carry the key.

## Resolution

`unit.population` carries the frontmatter value, or `internal` where the field is
absent — the reading `sdd_entity_population` already gives every rule that consults
the marker, so there is one default and not a second one. It is the entity's key
alone; every other kind emits none, and in the plan JSON that renders as `null`.

**The refusal object carries it too**, which the ticket did not ask for and the code
now does: a unit does not stop being externally populated because its document is
malformed, and without it `units[]` would read `null` for a refused entity and
`internal` for a clean one — the same fact answered two ways.

`emanate-plan.sh` carries it and **decides nothing with it**: no wave, no readiness
class and no refusal reads the key. The ticket's reason for the plan half — "so a
spawn brief can be built from the plan JSON alone" — is corrected in
`emanation-plan.md` rather than restated: a persona reads the marker from the derived
contract, and `run.md` § the spawn brief forbids a unit-specific "what you emit"
paragraph, so a brief that carried this fact would be writing the forbidden one. The
key is in the plan so a reader of that JSON can see which entities have no write path
without opening five contracts. `run.md` now uses the marker as that rule's worked
example, since it is exactly the shape of the trap.

`format-entity.md`'s "three tooling consequences" are four: the marker reaching the
derived contract is one, and the doc that defines the marker is where a reader looks
for what it does.

**Goldens.** `clean-entity-external` is `clean-entity` with the marker set and its
writing action removed — an external entity with a writer is `write-on-external`'s
fixture, not this one. It derives byte-identically to its sibling but for the key,
which is the whole assertion: the marker travels and changes nothing else. The three
clean entity fixtures assert the default and the two `emanate-plan` fixtures carry
the key, `null` on their action. `golden/emanate-derive` is 87 fixtures, from 86.

## Notes

Whether `population: external` should also change the **oracle** of `immutable` is the
ADR's question (`090-immutable-oracle-adr`), not this ticket's. This one only makes the
marker visible to the tool chain; what the tool chain does with it is decided there.
