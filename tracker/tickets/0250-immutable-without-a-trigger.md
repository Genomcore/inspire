---
id: 0250-immutable-without-a-trigger
title: "0250 — `immutable` forces a database trigger on a stack that keeps every rule in the application"
created: 2026-11-26
updated: 2026-11-26
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Mid
skills: [domain, code]
status: Open
blocked_by: []
related_to: [0143-store-side-constraints]
---

## Description

Met on `vitacora-core`, run `run-P1g5y4` (2026-11-26), filed as friction in the INSPIRE
feedback log, finding 2, `inspire-immutable-store-only`:
https://claude.ai/artifact/SaVrxv7wWgSPPmnfCLqLLx

### What happened

Vitacora keeps only the conventional constraints in its schema (PK, `NOT NULL`, `DEFAULT`,
`UNIQUE`, FK) and enforces every other rule in the application. Its `project-code-postgres`
profile says so in `## Persistence`: `immutable`, `len`, `pattern` and the rest are pure
functions in `src/{module}/domain/{entity}.rules.ts`, and "a migration carries no `CHECK` and
no trigger".

`platform.organizational_unit` marks `id`, `code`, `created_by` and `created_at` as
`immutable`. Its contract gives the four `field/*/immutable` claims the oracle `store`, and
`cite-claims` asserts a store claim against the schema. No schema object enforced them, so the
unit stopped with a spec issue. The project went back to a `BEFORE UPDATE` trigger for
`immutable` only (vitacora commit `31d106e`). That trigger is now the one unconventional object
in its schema. `len`, `pattern`, `enum` and the invariants stay in the application, and the
Factory accepts them there.

No action can write those fields anyway. The entity's write actions declare in `## Entities`:

| action | effect | fields written |
|---|---|---|
| `create` | creates the record | `id`, `parent_id`, `code`, `name`, … |
| `edit` | update | `name`, `description` |
| `move` | update | `parent_id` |

### What happens today

- `_references/keyed-heads.md` § Oracles puts `immutable` on the **store** row, alone among the
  value rules, and says why: "`immutable` is a store claim because nothing else can hold it".
  A profile that declares no column form for it is a rendering hole, and the unit's agent
  refuses the emission.
- `inspire-code-nestjs` renders it as a `BEFORE UPDATE` trigger in the migration that creates
  the table.
- No validator checks that an action whose effect is `update` does not list an `immutable`
  field as written. A spec that contradicts itself this way passes every check, and fails only
  at run time against the trigger.

### Why the store row is there

`ea9cf532` moved `immutable` from the test row to the store row after the first field run. At
the time, nothing enforced it. The entity unit has no write path to test, `readonly` is erased
before any write, and a raw `UPDATE` changed a primary key on a live database. Deferring the
claim to the unit that has the write path also failed on an entity with no update action at
all.

### What the field team proposes

1. **A validator** beside `action-fields-in-entity.sh`. For every field marked `immutable`, no
   action except the one that creates the record lists it as written in its `## Entities`
   table.
2. **The claim is guaranteed by the spec**, so it needs no trigger: code built from those
   contracts never writes the field.
3. Otherwise, `keyed-heads.md` states that `immutable` is always a schema object, whatever the
   profile says.

### Review

- **The validator stands on its own.** It catches a real contradiction that nothing catches
  today, and it costs nothing at run time. It also answers the case `ea9cf532` could not: an
  entity with no update action has no writer, so its `immutable` claims need no venue.
- **Dropping the trigger reopens `ea9cf532`.** The validator proves that no *declared* action
  writes the field. It does not prove that the code doesn't: a repository that saves the whole
  row, the next repository, or raw SQL. Without a store form, the claim still needs a test
  venue. That venue is each `update` action on the entity, whose unit asserts that the
  `immutable` fields come back unchanged. That is a new claim or a new oracle for those
  actions, and the Factory's deriver would have to derive it.
- **It is the same question as `0143-store-side-constraints`, in the other direction.** 0143
  proposes moving `len`, `pattern`, `min`, `max` and `enum` *into* the store ("as close to the
  store as the stack allows"). Vitacora's profile wants every value rule *out* of it. Both
  fit 0143's third form: store where the profile declares a column form, test otherwise. A
  profile like `project-code-postgres` then declares none, `immutable` included. The two
  tickets should be decided together, so `keyed-heads.md` § Oracles gets one rule.

## Acceptance criteria

- [ ] A validator reports an error when an action whose effect is not creation lists an
      `immutable` field as written in its `## Entities` table. It has fixtures for a passing
      entity and a failing one, and a row in `plugin/base/bin/README.md`.
- [ ] `keyed-heads.md` § Oracles states the oracle of `immutable` on a profile that declares
      no column form for it. Either it becomes a test claim asserted by each `update` action of
      the entity, with the validator covering entities that have none, or it stays a schema
      object on every stack and the section says so in words. The reasoning stays inline, as
      it is today.
- [ ] The answer agrees with `0143-store-side-constraints`: one rule in § Oracles covers
      `immutable` and the words 0143 moves.
- [ ] `derived-contract.md`'s oracle field, `inspire-domain`'s format references and
      `inspire-code-nestjs` § Persistence follow the answer.
- [ ] On `vitacora-core`, `platform.organizational_unit` builds with no trigger, or the spec
      says why it cannot.

## Notes

- **Factory.** The INSPIRE Factory assigns each claim's oracle in its own deriver. If
  `immutable` can be a test claim, or the `update` actions gain a claim, the deriver's oracle
  table, its fixtures and `cite-claims` follow. That work is filed in the Factory's tracker
  when this lands.
- The validator (the first criterion) can ship before the oracle decision. It changes no
  contract.
