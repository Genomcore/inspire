---
id: 090-emanate-wave-migrations
title: "090 — emanate: two contracters in one wave disagree on who applies a migration"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-09-09
epic: follow-up
size: S
importance: High
skills: [code]
status: Done
blocked_by: []
related_to: [090-emanate-runnable-worktree]
---

## Description

A wave runs its units in parallel, each in its own worktree, and every worktree points at
the **same** database and the same `_prisma_migrations` table. Both entity contracters in
the first field run saw the hazard and acted oppositely. `workspace.user` applied its
migration (`migrate diff --create-only`, then `migrate deploy`, correctly avoiding the
interactive `migrate dev`). `workspace.role` deliberately did not, so a sibling would not
read its history as drift. The database ended the wave with `users` applied and `roles`
pending. The two migration timestamps happened to order correctly, so `db:deploy` would
have resolved it — **luck, not design**: two entities whose timestamps landed the other
way would have applied out of order, and a third sibling running `migrate dev` would have
been offered a schema reset.

The same run produced the fact that decides the answer. An applied migration is
**immutable even for a comment**: Prisma stores a checksum per file, and one appended line
made `migrate dev` demand a reset while `status` and `deploy` still passed. So whoever
applies also freezes, and a persona that applies inside its worktree freezes a file the
overseers have not yet approved.

## Acceptance criteria

- [ ] Doctrine names **one** owner and one moment for applying migrations, and it is not
      a persona in its worktree. The candidates: the orchestrator at **verify**, against
      the integration branch, after the overseers approve — so nothing unapproved is ever
      frozen by a checksum; or a per-worktree schema (`?schema=<unit>`) so siblings never
      share migration history at all. The ticket picks one and `run.md` § verify (or §
      prepare) says it.
- [x] Ordering across siblings follows the wave's **promote order**, never file
      timestamps. Two migrations from one wave reach the turn branch in dependency order
      because that is the order their units merge.
- [x] `contracter.md` § Persistence is append-shaped gains the checksum fact: an applied
      migration is not edited, not even a comment, and a correction goes into the
      declarations or a new migration.
- [x] The contracter's own verification (`migrate status` reaching the plane, a
      throwaway-schema probe of store behaviours as `workspace.role` did) is named as
      allowed and distinguished from applying.

## Resolution

**The second candidate, generalized.** Doctrine (`run.md` § prepare) now says that
nothing the loop runs shares a migration plane and none of them is a plane the operator
keeps: each phase worktree, and verify, gets its own disposable one. Which mechanism
provides it — a schema, a database, a container — is the worktree recipe's business, so
the rule stays stack-agnostic where `?schema=` would not have.

That answers the first criterion by dissolving its reason rather than by its letter. It
does say a persona applies inside its worktree, which the criterion's lead clause rules
out; the clause was written for the *first* candidate, whose hazard is the checksum
freeze, and a plane that is thrown away records no checksum that outlives it. The
operator's own plane is never written at all — the loop merges nothing, so a run they
discard has to leave their database as it found it.

**One premise was wrong.** "The two migration timestamps happened to order correctly …
luck, not design" reads the hazard as an ordering one, and ordering is the part that was
never at risk. Waves are a Kahn layering over the ordering edges, so **a wave contains no
ordering edge by construction**: two same-wave migrations have no dependency between them
and commute in either order. Across waves the later one is generated after the earlier
promoted, so promote order and timestamp order agree and neither is doing any work. What
was luck is nothing; what was damage is the shared plane — a wave that ends half-migrated
leaves the *next* wave's units reading a sibling's absence as drift, and `migrate dev`
offering a reset.

One case is worth a second look and is out of this package's scope: a **deferred**
reference (a nullable `references(…)`) is exempted from ordering because the column fills
later, which is a claim about data and not about DDL — a constraint still needs its
target table. Two same-wave entities in that shape cannot be planned into an order. It
does not fail silently: the sibling's model is not in that worktree's schema at all, so
the contracter has nothing to render the reference against and refuses (§ Refusal — a
rendering hole is a readiness defect) rather than emitting a migration that would fail to
apply.

## Notes

`workspace.role`'s approach — probe the five store behaviours in a schema it created and
dropped, leaving `public` and `_prisma_migrations` untouched — is the model for what a
persona may do to the plane. It verified `23505`, `23514` and `23502` against real
Postgres and froze nothing.
