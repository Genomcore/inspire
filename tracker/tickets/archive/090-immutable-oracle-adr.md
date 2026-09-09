---
id: 090-immutable-oracle-adr
title: "090 — doctrine: `immutable` is a test-oracle claim no entity unit can cite"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-09-09
epic: follow-up
size: M
importance: Very High
skills: [code]
status: Done
blocked_by: []
related_to: [090-derive-population-marker, 090-reference-data-home, F06-tdd, F07-gates]
---

## Description

Four artifacts, each sound alone, compose into a unit that cannot pass its gate:

| artifact | what it says |
|---|---|
| `_references/keyed-heads.md` § Oracles | `immutable` is a **test**-oracle claim, with `enum`, `min`, `max`, `len`, `pattern`; store is `unique · nonnull · default · references` |
| `roles/contracter.md` § Emission | an entity's `fields` map to "the persistence model and one migration" — no method, no repository |
| `profiles/nestjs.md:395` | "`immutable` has no column form: it is enforced in the repository and asserted by a test" |
| `lib/gate-verdict.sh` | `GV-01` on any uncited `oracle: test` claim; `verdict = (findings == 0)` |

An entity unit therefore mints a claim whose only venue — a repository write path — it
does not emit, and no later phase of the unit emits it either. In the first field run
both entity units (`workspace.role`, `workspace.user`) were approved by both overseers at
the contracter boundary and then **stalled** at the tester handoff, because every
candidate test was either green on arrival (`readonly` is present in the declaration-only
tree), permanently red (Postgres happily runs `UPDATE users SET id = …`), or an import
that does not resolve. In the `gs` vault, **36 of 37** entity documents carry at least one
`immutable`, 145 occurrences in all — so on the current mechanics no entity unit in that
vault can clear its gate, and everything above entities is blocked. The two stalls cost
the run its goal.

The conversation after the run moved the diagnosis three times, and the last position is
the one this decision has to weigh. `immutable` is enforced by **nothing** in what the run
emitted: not the store (no trigger, no rule — the profile says so itself), not the type
(`readonly` is erased and the ORM write path never sees it), not a test (no venue). A raw
`UPDATE` changed a primary key on the live development database in one statement.
Exempting the claim would bless a property nothing checks.

Three resolutions, each with a real cost:

1. **Give `immutable` a column form.** The contracter emits a `BEFORE UPDATE` trigger
   (or the store's equivalent) that rejects a changed value, and `immutable` moves to the
   **store** oracle beside `nonnull`. Genuinely enforced against raw SQL and future
   repositories alike; genuinely testable as a store-violation test, green on arrival by
   design like `unique`. Cost: the persistence seed grows a trigger convention per
   framework profile, and `keyed-heads.md` § Oracles moves a word between tables.
2. **Treat `immutable` as realized by the declaration** and give it a gate status exempt
   from `GV-01` the way `store-uncited` already is. Cheapest, and it writes "nobody needs
   to verify this" into the tooling for a property with no teeth.
3. **A deferred oracle** — `{"oracle": "deferred", "to": "<unit>"}` naming the unit that
   emits the write path, which plan can then verify is in the wave graph. Keeps the gate
   honest, but `workspace.user` has no update action at all: the deferral target cannot
   test the property either, because no specified action ever mutates the field.

## Acceptance criteria

- [x] The decision lands in the **shipped doctrine**, not in `docs/adr/`: an ADR is
      template-side and never materializes, so the loop that has to obey the rule would
      never read it. `_references/keyed-heads.md` § Oracles is the deciding file — it
      moves `immutable` between the two rows (or names a fourth resolution) and carries
      the reasoning inline, the way that section already carries the reason the split
      exists at all.
- [x] The decision propagates to every file that restates it: `derived-contract.md`'s
      oracle split, `nestjs.md:395` and the framework profile's persistence seed, and
      `contracter.md` § Emission.
- [x] `GV-01`'s remedy string names only states the verdict schema has. Today it reads
      *"have the tester cite this claim, or report it as untestable"* and no field, status
      or exit represents the second branch. If the decision introduces a deferred or
      exempt status, it is counted in `summary` and never a finding — the `store-uncited`
      precedent in the same file.
- [x] Goldens follow the decision: a `canonical-entity` fixture with `immutable` derives
      the decided oracle; an `emanate-gate` fixture passes an entity unit whose only
      claims are store claims; `run.sh golden/emanate-derive golden/emanate-gate` green.
- [x] Two invariant shapes that stalled beside `immutable` are **named as out of scope,
      with an owner**: a cross-entity invariant (`inv/I1`: "every staff reference resolves
      to a row here" belongs on the referrer, `workspace.membership`) is a domain-skill
      question about where a claim is filed; a seed-data invariant (`inv/I2`: "the catalog
      ships with the platform") needs a declared home for reference rows, which no phase
      of the loop is chartered to fill. Neither is solved here; both are pointed at.

## Resolution — option 1, the column form

`immutable` is a **store** claim. The migration that creates the column carries the rule
that rejects a changed value, exactly as `unique` carries an index; the framework
profile's `## Persistence` declares the form, and the shipped `nestjs` seed declares a
`BEFORE UPDATE` trigger. Option 2 was rejected for writing "nobody needs to verify this"
into the tooling, and option 3 for deferring to a unit that cannot test the property
either.

The gate needed no new status: an uncited store claim is already `store-uncited`, counted
in `summary` and never a finding, so an entity unit whose fields carry only store
constraints now passes on the schema its contracter emitted. `GV-01`'s remedy dropped the
branch that named no state — it now reads *"have the tester cite this claim, or fix the
artifact that declares a claim no test can reach"*.

Of the two out-of-scope shapes, `inv/I1` was **answered in the same branch** rather than
filed — a cross-entity rule is declared where the reference is, which
`format-entity.md` § Constraints and invariants now states, and the headed spelling was
already an error under the V2 argument join. Only `inv/I2` needed a ticket:
`090-reference-data-home`.

Shipped in 0.9.3 (`ea9cf53`).

## Notes

This ticket is the deliberation record — the three options above and the caveats below —
because the decision itself has no room for them: `keyed-heads.md` states rules a project
obeys, not roads not taken. The release note goes in `CHANGELOG.md`. Nothing goes in
`docs/adr/`; the id keeps its `-adr` suffix only because two sibling tickets already cite
it by that handle.

The operator's two caveats in the post-run conversation are what moved the diagnosis and
they belong wherever the reasoning lands: *"by that logic nothing could be tested
first"* killed the misfiled-claim reading, since `form` with a compile stub sailed
through the same gate;
and *"not having an update action isn't itself a guarantee of the id not mutating"* killed
the wrong-oracle-class reading and produced the trigger demonstration. Option 1 is the
one that survived both.
