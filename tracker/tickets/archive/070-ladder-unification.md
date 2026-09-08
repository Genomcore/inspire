---
id: 070-ladder-unification
title: "070 — Q5: four maturity ladders, no shared grammar"
created: 2026-08-19
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: follow-up
size: M
importance: Mid
skills: [domain, adr, feature, spike]
status: Done
blocked_by: []
related_to: [070-format-doc-consolidation, 070-glossary-population]
---

## Description

Q5 from F02-contracts, deferred there as a shelf note and filed here so it survives that
ticket's archive. F02 pinned every artifact's *shape*; it left the maturity vocabularies
disagreeing. Four ladders ship today, one per layer, with no shared grammar and no stated
mapping between them:

| Layer | Field | Values |
|---|---|---|
| domain | `lifecycle:` frontmatter | `draft` → `accepted` → `stable`, plus `superseded` |
| ADR | `**Status:**` body line | `design` → `prototyped` → `implemented`, plus `superseded by [[x]]` / `rejected` |
| feature | `**State:**` body line | `🟡 Planned` → `🔵 In progress` → `🟢 Implemented` |
| spike | `status:` frontmatter | `active` \| `archived` \| `superseded` |

Sources: `inspire-domain/templates/{action,entity}.md.template`,
`inspire-adr/templates/adr.md.template:9-13`,
`inspire-feature/templates/use-case.md.template:11-12`,
`inspire-spike/templates/spike.md.template:4`.

Three carry a terminal `superseded`; three carry a three-rung forward progression that
means roughly the same thing in three vocabularies; only domain's is enforced by a
validator ramp, and only domain's lives in frontmatter where a script can read it cheaply.

## Acceptance criteria

- [ ] Decided: unify to one grammar, or ratify the divergence with the reason each layer
      needs its own words. Either outcome is recorded — this must stop being a shelf note.
- [ ] If unified: a stated mapping from every current value to its replacement, plus a hop
      that migrates existing projects (a ladder value is authored content, not a mirror).
- [ ] If unified: the ADR and feature ladders become machine-readable (frontmatter, or a
      pinned body line a validator can parse) so the ramp is not domain-only by accident.

## Notes

Filed at the 0.7.0 tracker reconciliation (2026-08-19), lifted verbatim in intent from
F02-contracts' "Ladder unification (Q5) deferred — shelf note". Not new scope.

Touches every layer's template at once, so it needs a release that already regenerates
the manifest — a property of the release, not a dependency on another ticket.

Do not confuse this with F04-mech's severity-grammar unification: that enum is *finding
severity*, this one is *artifact maturity*. Different contract, different files. An
earlier note here claimed the two were the same class of work; they are not.

**One of the three unfinished pieces of the contract wave.** F02-contracts and F03-style
shipped in 0.7.0 and are archived; what they deferred lives on as
[[070-format-doc-consolidation]] (one artifact shape, two files),
[[070-glossary-population]] (a contract rule reads a file nothing writes) and
[[070-ladder-unification]] (four maturity vocabularies). Separate work, one origin — read
the other two before scoping this one.

## Closed 2026-08-19 — divergence ratified

**Four layers, four vocabularies, and that is correct.** An ADR's `design → prototyped →
implemented` tracks *evidence of realization*; a domain object's `draft → accepted →
stable` tracks *contract firmness*; a feature's `Planned → In progress → Implemented`
tracks *delivery*; a spike's `active | archived | superseded` tracks *relevance*. They
rhyme without being the same measurement, and collapsing them into one enum would lose
the distinctions rather than unify them.

Nothing is blocked on this and nothing is broken by it. Each ladder is documented in its
own template, which is where an author meets it. The cost of unifying — every layer's
template at once, plus a migration hop for authored values — is real; the benefit was
never named beyond tidiness.

**On the filing itself:** this was a shelf note inside F02-contracts, promoted to a
ticket on 2026-08-19 so archiving F02 would not bury it. Promoting it was the wrong call
— a note nobody would schedule is a note, and the right move was to answer it on the
spot, which is what this closure does. Recorded here as the worked example of rule 2.
