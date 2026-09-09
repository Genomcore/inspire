---
id: 090-nestjs-stamps-seed
title: "090 — nestjs profile: § Persistence adds stamps the entity never declared"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: [code]
status: Open
blocked_by: []
related_to: [090-immutable-oracle-adr]
---

## Description

`profiles/nestjs.md` § Persistence, "Keys and stamps": *"`id UUID DEFAULT
gen_random_uuid()` primary key; `created_at` / `updated_at` as `TIMESTAMPTZ`."* Read as a
convention, it puts two stamp columns on every table. The domain layer already decides
this per entity: stamps are declared **as fields**, and the vaults that follow the
format discriminate — in `gs`, five entities declare both stamps, five declare only
`created_at`, and `workspace.role` declares neither, because nothing writes it.

In the first field run two sibling contracters in one wave read the seed differently.
`workspace.role` emitted `created_at` and `updated_at`, citing the seed; `workspace.user`
emitted only the `created_at` its contract declared and refused `updated_at` as "a column
with no domain field and no claim behind it". The quality overseer rejected `role` on the
evidence that if the seed governed, every stamp declaration in the domain layer would be
redundant and the single-stamp entities would silently acquire a column their authors
withheld. The decisive detail was `updated_at` itself: `@updatedAt` fires only on an ORM
update, nothing writes that table, so the column would hold the insert timestamp forever
under a name that promises last-change — in a product whose stated purpose is an audit
trail. One rework cycle, on a contradiction between a seed and the format it serves.

The same emission had already overridden three other clauses of the same Seed section,
correctly (TypeORM → Prisma, `src/migrations/` → the project's path, `infrastructure/` →
`packages/domain`). A seed the contracter must override four times is not seeding.

## Acceptance criteria

- [ ] "Keys and stamps" says what it means: the `id` default is a convention; a stamp is
      a column **only when the entity declares the field**, and its type rendering is the
      convention. No profile clause adds a column the contract does not carry — the
      field→column rule that `schema.prisma`'s own header already states.
- [ ] `contracter.md` § Emission's entity row points at the rule, so a contracter reading
      the role doc first arrives already knowing that persistence is field-driven.
- [ ] The other framework profiles that carry a § Persistence (`angular`, `ios`,
      `android` where applicable) are read for the same shape and fixed or confirmed
      clean, in the same change.
- [ ] **Or Done with zero code changed**, if the ruling is that a Seed section is
      *expected* to be edited by every project and the template's job is only to say so —
      then the Seed marker's definition gains that sentence and this closes.

## Notes

The `immutable` line two bullets above this one (`nestjs.md:395`) is the ADR's
(`090-immutable-oracle-adr`) and is deliberately not touched here; the two will land in
the same file and should be sequenced so the ADR's edit is not clobbered.
