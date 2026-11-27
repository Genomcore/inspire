---
id: 0230-guard-before-its-providers
title: "0230 — A guarded action is planned before the units its guard reads"
created: 2026-11-27
updated: 2026-11-27
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [domain, code]
status: Open
blocked_by: []
related_to: [B3-entry-points, 090-actor-head-without-a-role]
---

## Description

Met by the Genomics Studio team in run 19 (2026-11-26, INSPIRE 0.23.0, Factory 0.25.0), filed
as finding F26 of their Factory run findings, still present on Factory 0.26.0:
https://claude.ai/artifact/G2pMLju5AQJUDbrBCHDgSC#F26

### What happened

`panels.panel.create`, `delete`, `import`, `parse_entries` and `set_status`, and
`cases.case_relationship.retract` each stopped. Each has an `actor(…)` precondition, so each
derives a `binding/guard` claim. The project's `inspire-code-nestjs` renders that guard as
`@UseGuards(AuthGuard, RolesGuard)`, which reads the session, the API key, the users and
their memberships. None of those units had been built, and the agents could not read their
contracts: `claim_fingerprints` answered that `users.membership` is "neither the assigned
unit, nor one of its members, nor a unit it requires".

Every guarded action in the plan has the same gap. The project has 119 of them, and none
lists the auth units in `requires:`. No INSPIRE rule asks it to.

The same units also lacked `audit.entry.record`. That half was the project's: an action that
calls another lists it in `requires:`, and the team has added it.

### What happens today

- [`derived-contract.md`](../../plugin/base/skills/_references/derived-contract.md)
  § Binding claims derives `{action}/binding/guard` "with no authoring" from the binding
  profile's `## Bindings`. It derives a claim and nothing else: no `requires` edge.
- A unit's `requires` come from its `requires:` frontmatter, the entities it touches and its
  links. The planner orders on those edges only, so a guarded action has no edge to the units
  its guard reads.
- Since a unit may not build what another unit owns, the action's agent can neither build the
  guard's inputs nor wait for them. It stops. F20, F21 and F25 have the same cause. Run 9,
  before that rule, built the guard inside each action.

### What the field team proposes

1. The planner adds the units that provide the guard to every action with an `actor(…)`
   precondition.
2. Or the profile names them, and the planner reads it.

### Review

- **The planner cannot guess them.** Which units a guard reads depends on how the project
  designs its auth, so the answer has to be written down once, by the project. Road to 1.0
  also keeps the planner off the KB: it reads only the inventory's `requires`, and the spec's
  producer writes them (D-INV-2, D-INV-4).
- **Listing them in every action's `requires:` is the wrong place.** It is 119 copies of one
  project-wide rule, against the "no authoring" of § Binding claims and against D-BIND-1: the
  binding rule is decided once, for the whole product.
- **The binding rule names them.** `## Bindings` gains a `### Guard providers` table, one
  row per unit the guard reads or that builds it:

  | unit | provides |
  |---|---|
  | `auth.session` | the session `AuthGuard` reads |
  | `auth.api_key` | API-key authentication |
  | `users.user` | the caller |
  | `users.membership` | the roles `RolesGuard` checks |

  Every action that selects a guard row keyed `actor(` gets an ordering edge to each of those
  units, with `source: contract`. The planner and `claim_fingerprints` need no change: they
  already read `requires`.
- **The table moves no fingerprint.** A binding claim hashes what its test sends and checks
  (D-BIND-3). The guard test sends a request with and without the role, and that does not
  change with who provides the guard. So the new table is never hashed, and adding it
  re-emanates nothing. The published Factory reads only `### Routes`, `### Plurals` and
  `### Guard`, so it ignores the table.
- **Cycles.** A provider that is itself a guarded action closes a cycle. The plan checks
  already refuse a cycle of ordering edges (D-ASM-12). A validator reports it earlier.
- **The seed cannot fill it.** `inspire-code-nestjs` does not know a project's unit ids, so
  its seed ships the table empty, with one sentence on what it is for.
- **Open: who builds `AuthGuard` and `RolesGuard`.** The rule that a unit may not build what
  another owns only works if the guard code has an owner. The proposal is that the owning
  unit is a row of the table as well. The answer may be another one, and the acceptance
  criteria leave room for it.
- **D-BIND-2 lists three tables.** A fourth one changes that decision, so the design needs
  the maintainers' agreement before it is built.

## Acceptance criteria

- [ ] The maintainers agree where the guard's providers are declared. If it is not a
      `### Guard providers` table in `## Bindings`, the criteria below follow the chosen
      form.
- [ ] `derived-contract.md` § Binding claims states that an action with an `actor(…)`
      precondition requires, with an ordering edge, every unit the table names, and that
      the table is never hashed into a binding claim.
- [ ] `inspire-code-nestjs` § Bindings ships the table empty, says what a row means, and
      says which unit owns the guard code.
- [ ] A validator warns when some action has an `actor(…)` precondition and the binding
      rule names no provider. It reports an error when a provider names no unit of the KB,
      or is an action with an `actor(…)` precondition. It has fixtures and a row in
      `plugin/base/bin/README.md`.
- [ ] A project with no table derives the same contracts and fingerprints as today.

## Notes

- **Factory.** The edge is added by the deriver, which still lives in the INSPIRE Factory
  until D-INV-2 moves it into the spec. Its reading of the table, its fixtures and a test
  that a guarded action's `requires` holds the providers are filed in the Factory's tracker
  when this lands. That release ships before INSPIRE's or with it.
- **Run length.** Each guarded action waits for the providers, so the plan's critical path
  grows by their depth, once, at the start of a first build. They are real dependencies.
  Today the run pays for them with stopped units instead.
