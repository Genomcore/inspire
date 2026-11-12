---
id: 0143-store-side-constraints
title: "0143 — `len`, `pattern`, `min` and `max` are test claims, so raw SQL writes past them"
created: 2026-11-02
updated: 2026-11-02
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [code]
status: Open
blocked_by: []
related_to: [090-immutable-oracle-adr, B5-error-codes-on-the-wire]
---

## Description

`_references/keyed-heads.md` § Oracles files `enum`, `min`, `max`, `len` and `pattern`
under the **test** oracle, so no stack skill renders them in the store. The NestJS skill's
persistence rules turn only store claims into column constraints (`unique`, `nonnull`,
`default`, `immutable`), and the TypeScript skill's *Mapping tokens* sends
`matches {pattern}` to "— (validator)" with no SQL form.

A first Factory run on a test project (entity `catalog.book`, INSPIRE 0.13.0 skills) shows
the result. The entity declares `title` and `author` as `len(1,100)` and `isbn` as
`pattern(/^97[89][0-9]{10}$/)`:

- the migration carries `NOT NULL`, `UNIQUE`, `DEFAULT NOW()` and the immutability trigger,
  and **no `CHECK`** for length or pattern;
- the agent put the three rules in a domain validator with its own unit test, which cites
  all 13 `len` and `pattern` claims;
- nothing calls that validator yet, so the claims read as covered while nothing enforces
  them; and even once an action calls it, a raw `INSERT` or `UPDATE` writes a 500-character
  title or a non-ISBN without complaint.

This is the argument that moved `immutable` to the store row in `090-immutable-oracle-adr`:
a rule that only the repository knows is invisible to raw SQL and to the next repository.
That ticket moved one word and left the other five where they were.

`enum` is already an exception in practice: it sits on the test row, yet the TypeScript
skill renders it as `TEXT CHECK (col IN (...))` (*Rendering*, `enum<A,B,C>` row).

### Why the split was drawn this way

The test row dates from `9609f7c` (2026-08-25), which records no reason. The recollection
of its author is that it normalised constraints across stores that do not share the same
capabilities. Rereading it in the maintainers' channel (2026-11-02), the proposed direction
is the opposite: **assert each rule as close to the store as the stack allows**. When the
implementer knows the store is SQL and it can express `min`, `max`, `len` or a pattern at
table level, the table carries it; where the store cannot, the rule stays in code.

## Acceptance criteria

- [ ] `_references/keyed-heads.md` § Oracles states the rule for `enum`, `min`, `max`,
      `len` and `pattern` and carries its reasoning inline, as it already does for
      `immutable`. Either they move to the store row, or the section names a third form
      ("store where the profile declares a column form, test otherwise") and says how a
      profile declares it.
- [ ] Every file that restates the split follows: `derived-contract.md`'s oracle field,
      `inspire-domain`'s format references and examples that name an oracle.
- [ ] The NestJS skill's `## Persistence` declares the column form of each moved word
      (for example `CHECK (char_length(col) BETWEEN n AND m)`, `CHECK (col ~ '…')`,
      `CHECK (col >= n)`), and the TypeScript skill's *Mapping tokens* gives
      `matches {pattern}` its SQL expansion. A pattern that the store's regex dialect
      cannot express is named, with what happens then.
- [ ] The skills say whether the application keeps a validator beside the `CHECK`, for a
      readable API error rather than a constraint violation, and where that error is
      specified (see `B5-error-codes-on-the-wire`).
- [ ] If the review keeps the current split, `keyed-heads.md` § Oracles says why (which
      stores lack the capability), and the ticket closes **Done** with no other change.

## Notes

- **Factory.** The INSPIRE Factory derives contracts with its own deriver, which assigns
  each claim's oracle, and its gate counts an uncited store claim without a finding. A
  change to the split needs matching Factory work: the deriver's oracle table and its
  fixtures. That work is filed in the Factory's tracker when this lands.
- **Where it came from.** Thread in `#inspire_mantainers`, 2026-11-02, between Irene González
  and Darío Blasco, after reviewing the code the Factory emanated for `catalog.book`.
- Two homes were mentioned for the "as close to the store as possible" logic: the
  reference and the code skills, or an ADR installed in the project. Choosing one is part
  of this ticket.
