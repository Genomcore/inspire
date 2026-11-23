---
id: B3-overridable-types
title: "B3 — Default semantic types a project can override"
created: 2026-10-27
updated: 2026-11-17
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: L
importance: High
skills: [domain, code, bootstrap]
status: Open
blocked_by: []
related_to: [F14-semantic-types, B1-config-replaces-bootstrap, 0180-derive-only-refusals]
---

## Origin

The INSPIRE maintainers held the third session of a design review on 2026-10-27 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** INSPIRE ships a default set of semantic types and value objects, and every
project can override, extend or customise them, as long as it says how each one behaves.
Arrays must be supported. The basic list is reviewed against the stack, and the project
config records which types are available and how.

## Description

### What happens today

`inspire-domain/references/type-mapping.md` defines a **closed** universal vocabulary:
`email`, `uuid`, `timestamp` (ISO-8601 by rule), `date`, `password`, `string`,
`integer`, `number`, `boolean`, `json`, `enum<…>`. It has no array or list, so a list
input falls back to `json`, which validates nothing. A project can only *add* types, in
`00_bootstrap/semantic-types.md`, each on a universal base type. It can't change a
universal one: changing one "is a runtime change".

The language profile renders the types (`profiles/typescript.md`), and emanation refuses
a type with no rendering. `password` already carries the behaviour the review wanted to
keep: never stored in plaintext, never logged, never read back.

`F14-semantic-types` (that three-way split) is still marked Open, but what it asks for
appears to have shipped.

### What this ticket asks for

- The universal vocabulary becomes a **shipped default**, not a closed list. A project
  can override a default (for example a different date format than ISO-8601), add its
  own types, and say how each one behaves.
- Add a collection type (`array<T>` or `list<T>`), whatever the target calls it.
- A support table: for each type, whether the stack has it natively or the domain
  implements it as a value object. A type that is used but missing from the table is a
  finding.
- Review the basic list against the current stack. The review assigned this to four of
  its maintainers.
- Keep the semantic types that carry behaviour, such as credentials, so the spec never
  has to repeat "don't log it, don't store it".
- Setup offers the defaults in one step. It doesn't ask about each type.
- **A validator for the Type cells, which can ship first.** A new rule in `review.sh`'s
  default list reads every Type cell: entity `## Fields`, and action inputs, outputs and
  entities. Each cell resolves to a universal type or to a `semantic-types.md` row whose base
  is universal. It reports an empty cell, an unknown type, a project type with no universal
  base, and a rejected alias with its replacement (`int` → `integer`). A finding is a warning
  at `draft` and an error from `accepted` on. It checks today's vocabulary, so it does not
  wait for the rest of this ticket; the collection type and the overrides then extend it.
- **Nested records.** The collection type also covers a row with its own fields, such as
  `items[].reservation`, and `format-action.md` § Outputs says how an output writes
  `{field}[].…` rows.
- `type-mapping.md` stops saying that an unknown project type "is caught at emanation, not
  authoring time".

### Open questions

- Where does the table live: the spec config, `00_bootstrap/semantic-types.md`, or the
  language profile? Each fits a different part.
- In code, where do custom value objects go? The review said in the domain: in a module
  if one module uses it, and in a common module if several do. Is that profile doctrine?
- Should `F14-semantic-types` be closed, after checking its three criteria against the
  shipped tree?

## Acceptance criteria

- [ ] `type-mapping.md` describes the universal vocabulary as overridable defaults, and
      says how a project overrides one and states its behaviour.
- [ ] A collection type exists in the vocabulary and has a rendering in every language
      profile.
- [ ] The support table exists, and a used type missing from it is reported as a
      finding, with fixtures.
- [ ] The basic list has been reviewed against the current stack, and the outcome is
      recorded in this ticket's close note.
- [ ] Setup offers the defaults in one step.
- [ ] A rule in `review.sh`'s default list reports an empty Type cell, an unknown type, a
      project type with no universal base, and a rejected alias with its replacement, as a
      warning at `draft` and an error from `accepted` on. Fixtures cover each case, in entity
      fields and in action inputs, outputs and entities.
- [ ] `format-action.md` § Outputs and `type-mapping.md` show how an output types a list of
      rows and a nested record, with an example.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

**Amended 2026-10-28 (tracker pass).**

- *F14 is closed.* Its three criteria were checked against the 0.12.1 tree and it is
  archived as Done, so the third open question has its answer.
- *Factory port.* The INSPIRE Factory derives contracts with its own reader of the KB. A
  collection type and overridable defaults change what that reader accepts, and the
  matching change is filed in the Factory's tracker when this ticket's format lands.

**Amended 2026-11-17 (a governed project's Factory run).**

A governed project's first full INSPIRE Factory run (Factory 0.18.0, 2026-11-16) built 54
units and refused six at derive, before any agent started. The six refusals blocked seven
more units: the project's API bundle and six screens. Every refused spec had passed
`review.sh` and been promoted to `accepted`. Five of the six were type refusals:

| Refused unit | What the deriver refused |
|---|---|
| `accounts.user.list` · `reservations.reservation.list` · `sharing.friendship.list` | output `items` typed `list` |
| `wishlists.wishlist.get` | `items` typed `list`; `items[].reservation` typed `object` |
| `wishlists.wishlist.list` | `items` typed `list`; input `limit` and `items[].item_count` typed `int` |

- *No rule checks a Type cell.* No script under `plugin/base/bin/` reads
  `semantic-types.md` or compares a Type cell with the universal list, and `type-mapping.md`
  says so ("caught at emanation, not authoring time"). It also lists `int` as a rejected
  alias of `integer`, and no script enforces that. The validator above closes the gap.
- *Four list actions had no type to use.* With no collection type and no nested record, the
  authors invented `list` and `object`. The project now declares both as project types on
  `json`, which the deriver accepts.
- *Factory port.* The Factory's own list of universal types changes in the same release as the
  collection type, or the deriver refuses the new type. The Factory note above covers it.
