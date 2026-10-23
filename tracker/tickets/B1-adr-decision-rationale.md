---
id: B1-adr-decision-rationale
title: "B1 — an ADR mixes the decision with its rationale in one file"
created: 2026-10-23
updated: 2026-10-23
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: L
importance: High
skills: [adr]
status: Open
blocked_by: []
related_to: [B1-decisions-in-context, B1-kb-structure]
---

## Origin

The INSPIRE maintainers held a design review on 2026-10-23 while preparing the training of
new INSPIRE operators. This ticket records one of its decisions. The review's working notes
are not public, so this ticket states everything needed to act on the decision.

**Decision:** split each ADR into two files. One holds the decision and the other holds
the rationale.

## Description

An ADR in a project (template: `plugin/base/skills/inspire-adr/templates/adr.md.template`)
holds two kinds of content:

- **The decision**: a short, binding statement. For example, "authentication is
  solved with the Better Auth library."
- **The rationale**: context, options weighed, consequences and alternatives
  rejected. It explains the choice but constrains nothing.

The two are read at different times. Every session that specifies or builds needs every
decision, and needs it often. The rationale is read only when someone questions or
supersedes a decision. With both in one file, a reader who needs only the decisions
reads all the reasoning too. `B1-decisions-in-context` has to avoid that cost.

Proposed shape:

- **Decision file**: title, maturity status, `surfaces:`, modules affected, the decision
  as one or a few imperative statements, and a link to the rationale.
- **Rationale file**: context, consequences, breaking changes, alternatives considered,
  related ADRs.

## Acceptance criteria

- [ ] Both file shapes are defined in `plugin/base/kb/01_adr/README.md`, and the
      template ships for both.
- [ ] The id rule is stated. The pair shares one id, following
      `docs/adr/adr-decision-record-ids.md`, and wikilinks resolve to the decision file.
- [ ] Maturity and immutability are assigned. An ADR at `implemented` maturity is
      immutable today: changing it means superseding it. The ticket states whether that
      covers both files or only the decision file.
- [ ] `inspire-adr`'s `create`, `update`, `promote` and `supersede` subcommands write
      and check the pair. The review rules that read ADRs read the new shape.
- [ ] Trust stamps (`plugin/base/bin/trust.sh`) state which file they cover, or that
      they cover both.
- [ ] Existing single-file ADRs keep working. Either a reader accepts both shapes, or an
      explicit migration moves them in line with `docs/adr/adr-upgrade-path.md` decision
      D10, which keeps the KB additive.

## Notes

- This ticket changes ADRs inside projects. The hand-written ADRs in this repository's
  `docs/adr/` are out of scope unless the split is adopted for them too.
