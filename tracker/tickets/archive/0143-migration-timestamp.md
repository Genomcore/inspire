---
id: 0143-migration-timestamp
title: "0143 — the NestJS skill does not say which instant names a migration"
created: 2026-11-02
updated: 2026-11-02
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: [code]
status: Open
blocked_by: []
related_to: [0143-store-side-constraints]
---

## Description

`inspire-code-nestjs` § Persistence says migrations live in `src/migrations/`, "one
timestamp-named file per change". It does not say which instant. Two Factory runs on a
test project (INSPIRE 0.13.0 skills) resolved it in two ways:

| unit | how the agent chose the number | migration |
|---|---|---|
| `catalog.book` (2026-10-29) | the current time, `date +%s%3N` | `1793255939000-create-books-table.ts` |
| `catalog.copy` (2026-11-02) | the previous migration plus one second | `1793255940000-create-copies-table.ts` |

The second form breaks when two emanations run at once: Factory `concurrency` above 1, or
two people emanating from the same base. Each agent sees the same last migration and can
pick the same number.

TypeORM 0.3.31 accepts that. It rejects only repeated class names
(`checkForDuplicateMigrations`), sorts by the number, and leaves two equal numbers in the
order its file `glob` returned them. Measured on 2026-11-02 with two migrations numbered
`1800000000000`, where `beta` references `alpha`:

| files | load order | result |
|---|---|---|
| `…-create-alpha.ts`, `…-create-beta.ts` | beta, alpha | fails: `relation "alpha" does not exist` |
| `…-a-create-beta.ts`, `…-b-create-alpha.ts` | alpha, beta | applies both |

On macOS the load order came out reverse-alphabetical and stable. Nothing documents it, so
another file system can order them differently. With the current time, two units would
have to start the same file in the same millisecond.

## Acceptance criteria

- [ ] `inspire-code-nestjs` § Persistence says the number in a migration's name is its
      creation instant in milliseconds (`date +%s%3N`), never one derived from the
      previous migration.
- [ ] The rule says the number stays the last 13 characters of the class name. TypeORM
      reads the instant from `migrationClassName.substr(-13)` and refuses a name that does
      not end in one.

## Notes

- **Agreed in `#inspire_mantainers`, 2026-11-02:** the current time. Not ruled out for
  later: combining it with the run's id, or a hash of it, once the INSPIRE Factory's
  control plane exists, so that two units sharing an instant still get distinct names.
  Because TypeORM reads the last 13 characters, that suffix would go before the number,
  not after it.
- **Factory.** No Factory change is needed for the current-time rule. The run-id idea
  would need the Factory to hand the run's id to its agents. That work is described in
  the Factory's tracker when it is taken up.
- A migration merged after another with a later number is a separate problem, and the
  number's source does not fix it. TypeORM 0.3 runs it anyway: the check that rejected a
  migration older than the last one applied is commented out in `MigrationExecutor`.
