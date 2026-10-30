---
id: B1-adr-decision-rationale
title: "B1 — an ADR mixes the decision with its rationale in one file"
created: 2026-10-23
updated: 2026-10-30
reporter: "@dario.blasco"
closed_by: "@djessy.czaplicki"
closed_at: 2026-10-30
epic: roadmap
size: L
importance: High
skills: [adr]
status: Done
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

- [x] Both file shapes are defined in `plugin/base/kb/01_adr/README.md`, and the
      template ships for both.
- [x] The id rule is stated. The pair shares one id, following
      `docs/adr/adr-decision-record-ids.md`, and wikilinks resolve to the decision file.
- [x] Maturity and immutability are assigned. An ADR at `implemented` maturity is
      immutable today: changing it means superseding it. The ticket states whether that
      covers both files or only the decision file.
- [x] `inspire-adr`'s `create`, `update`, `promote` and `supersede` subcommands write
      and check the pair. The review rules that read ADRs read the new shape.
- [x] Trust stamps (`plugin/base/bin/trust.sh`) state which file they cover, or that
      they cover both.
- [x] Existing single-file ADRs keep working. Either a reader accepts both shapes, or an
      explicit migration moves them. That migration must respect the upgrade rule in
      `docs/adr/adr-upgrade-path.md`, section "The KB is additive in both init and
      update".

## Resolution

Every ADR is a pair that shares one id: the decision `adr-{slug}.md` and the rationale
`adr-{slug}.rationale.md` beside it. The dotted suffix cannot collide with a real slug,
and `[[adr-{slug}]]` still reaches the decision by name.

Every acceptance criterion holds:

- `plugin/base/kb/01_adr/README.md` defines both shapes, and `inspire-adr` ships
  `adr.md.template` (the decision) and `adr.rationale.md.template`.
- The id is the decision's filename without `.md`; the rationale shares it.
  `sdd_find_adrs` returns decisions only and `sdd_find_adr_rationales` the rationales,
  so the glob stays the catalog. `adr-maturity-matches-features` reads a link to a
  rationale as a link to its decision, and `wikilinks-resolve` resolves both names.
- Status, `surfaces:` and the modules live in the decision only. At `implemented`
  **both** files are immutable: a change to either one means superseding. Moving text
  between the two files without changing a word is not a change, so `migrate` is
  allowed at every maturity.
- `create`, `update`, `promote` and `supersede` write the pair, and the new `migrate`
  splits old ADRs. `sections-present` checks each file of the pair and the pair itself
  (each section in the right file, neither file without the other); `prose-style`
  reads both files.
- Trust stamps cover one file each: the decision and the rationale are two artifacts,
  and `promote` proposes endorsing each separately (`_references/trust-stamps.md`).
- Existing single-file ADRs keep working: the validators still check their five
  sections and report them, as a warning, as waiting for the migration. The migration
  is explicit, as `adr-upgrade-path` D10 requires: `.inspire/bin/adr-split.sh` moves
  every line verbatim, `/inspire-adr migrate` runs it and offers to move reasons left
  in `## Decision` to the rationale, and `/inspire:update` offers the migration at the
  end of a run without running it.

## Notes

- This ticket changes ADRs inside projects. The hand-written ADRs in this repository's
  `docs/adr/` are out of scope unless the split is adopted for them too.
