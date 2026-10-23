---
id: B1-spikes-out-of-the-kb
title: "B1 — spikes are tracked inside the KB, but they are experiments outside it"
created: 2026-10-23
updated: 2026-10-23
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [adr, spike]
status: Open
blocked_by: []
related_to: [B1-kb-structure]
---

## Origin

The INSPIRE maintainers held a design review on 2026-10-23 while preparing the training of
new INSPIRE operators. This ticket records one of its decisions. The review's working notes
are not public, so this ticket states everything needed to act on the decision.

**Decision:** a *spike* stays a concept in INSPIRE, but the KB stops tracking spikes. A
spike is a vertical experiment, built in its own repository outside INSPIRE, to prove
that one hard thing works. Its learnings are written into the specification, mostly as
ADRs plus the features, entities and screens those ADRs affect. The spike itself has no
file in the KB.

## Description

Today the KB has a layer for spikes, which this decision removes:

- `inspire_kb/06_spikes/` holds one `{name}.md` per spike: repository link, imported
  learnings and gap analysis.
- The `inspire-spike` skill (`register` and `capture` subcommands) maintains that layer.
- Fourteen other files under `plugin/base/` mention `06_spikes` or `inspire-spike`.
  Among them are the KB README, the `02_modules`, `03_features` and `98_lessons`
  READMEs, `trust.sh`, the root `CLAUDE.md` template, and the `prototype`, `module` and
  `feature` skills.
- ADR maturity `prototyped` means "validated in an external spike". `inspire-adr`'s
  `promote` subcommand requires a `**Prototype:**` line that points at the spike's
  repository. That pointer still works without a spike layer, because it names a
  repository, not a KB file.

### Open question: a spike summary artifact

The review suggested a small "spike summary" artifact as a stable reference for ADRs to
cite in place of a repository URL, which can go stale or be archived. It is worth adding
only if a repository link in the ADR's `**Prototype:**` line is not enough. Answering "a
link is enough" closes the question without a new artifact.

## Acceptance criteria

- [ ] `06_spikes/` is removed from the KB skeleton (`plugin/base/kb/`). `inspire-spike`
      is removed from the payload, or reduced to a single capture step that writes
      straight into ADRs and other spec, with no spike file of its own.
- [ ] No file under `plugin/base/` still points at `06_spikes` or `inspire-spike`.
- [ ] `inspire-adr`'s evidence rule for `prototyped` names its new target: a repository
      link, or the spike summary if one is added.
- [ ] The spike summary question is answered and the answer is written down. "Not
      needed" is a valid answer.
- [ ] Upgrade behaviour is checked against a fixture:
  - An unedited shipped `inspire-spike` file is deleted, because the upgrade merge marks
    files that INSPIRE no longer ships as "no longer part of INSPIRE".
  - An edited one is kept.
  - An existing project's `06_spikes/` content is left in place. Under
    `docs/adr/adr-upgrade-path.md` decision D10, the KB is additive and has no delete
    outcome.
  - The upgrade report tells the operator that the spike layer is retired.

## Notes

- What a project does with its existing spike repositories (archive, delete or keep) is
  that project's decision, not the runtime's. So are the broken links that follow. This
  ticket only adds the retirement notice to the upgrade report.
