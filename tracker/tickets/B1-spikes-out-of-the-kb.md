---
id: B1-spikes-out-of-the-kb
title: "B1 — spikes are tracked inside the KB, but they are experiments outside it"
created: 2026-10-23
updated: 2026-10-30
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
- [ ] `/inspire-extract` has a spike mode: pointed at a spike's repository, it returns
      ADR, feature and entity candidates with their evidence. *Added 2026-10-30:* see
      the fifth design-review amendment below, which also drops the "reduced to a
      capture step" option of the first criterion.
- [ ] No file under `plugin/base/` still points at `06_spikes` or `inspire-spike`.
- [ ] `inspire-adr`'s evidence rule for `prototyped` names its new target: a repository
      link, or the spike summary if one is added.
- [ ] The spike summary question is answered and the answer is written down. "Not
      needed" is a valid answer.
- [ ] Upgrade behaviour is checked against a fixture:
  - An unedited shipped `inspire-spike` file is deleted, because the upgrade merge marks
    files that INSPIRE no longer ships as "no longer part of INSPIRE".
  - An edited one is kept.
  - An existing project's `06_spikes/` content is left in place. The upgrade rule in
    `docs/adr/adr-upgrade-path.md`, section "The KB is additive in both init and
    update", gives the KB no delete outcome.
  - The upgrade report tells the operator that the spike layer is retired.

## Notes

- What a project does with its existing spike repositories (archive, delete or keep) is
  that project's decision, not the runtime's. So are the broken links that follow. This
  ticket only adds the retirement notice to the upgrade report.

**Amended 2026-10-30 (fifth design-review session): what a spike produces.**

- *Decision:* a spike is throwaway. What it produces is conclusions, ADRs and
  specification, never code to keep: the product is built from the spec, not from the
  spike's code. A spike is not held to INSPIRE's tests or gates. It may use the stack
  skills when realism matters, for example in a performance spike, so its conclusions
  reflect code written the way the product's will be. INSPIRE needs a way to extract a
  finished spike's conclusions into the KB.
- *Change:* the capture step this ticket allows becomes a mode of `/inspire-extract`. It
  is pointed at the spike's repository and returns ADR, feature and entity candidates
  with their evidence. The option of keeping a reduced `inspire-spike` is dropped.
- *Not now:* a "light mode" that applies some gates and skips tests was proposed and
  deferred. A spike carries no INSPIRE test or gate requirement.
- *Factory design:* the INSPIRE Factory's control-plane design gives extract two modes.
  `intent` reads code without running it and writes KB drafts, so the spike mode can
  build on it for entities and actions. It does not capture conclusions or ADRs, which
  is the part this decision needs most. `adopt` moves existing code into the product,
  and it is not for spikes.
- *Open:* when a team wants to keep a spike's code anyway, is `adopt` the supported
  path, or is the answer always "re-specify and build"?
