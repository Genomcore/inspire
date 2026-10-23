---
id: B1-operator-profiles
title: "B1 — trust and guardrails treat every operator the same"
created: 2026-10-23
updated: 2026-10-23
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: XL
importance: Low
skills: [workspace]
status: Open
blocked_by: []
related_to: [B1-config-replaces-bootstrap]
---

## Origin

The INSPIRE maintainers held a design review on 2026-10-23 while preparing the training of
new INSPIRE operators. This ticket records one of its decisions. The review's working notes
are not public, so this ticket states everything needed to act on the decision.

**Decision (long term):** map each operator of a project to one or more proficiency
profiles. Evolve INSPIRE's trust and guardrail systems so they take those profiles into
account.

## Description

INSPIRE already separates two operator roles: the functional operator specifies the
product, and the technical operator reviews and builds it (see
`B1-config-replaces-bootstrap`). Within a role, every operator is treated the same. An
endorsement from someone new to a domain weighs the same as one from the domain's
owner. No guardrail adjusts to who is working.

Direction:

- A **proficiency profile** records which areas an operator is proficient in, such as
  the product domain, a stack layer, or security.
- A **scanner** proposes or updates those profiles.
- The **trust and guardrail systems** read the profiles.

Open design questions:

- **Identity.** `docs/adr/adr-artifact-trust.md` records who endorsed an artifact.
  `docs/adr/adr-upgrade-path.md`, decision D11 ("Git is read-only against the
  operator's repository"), means authorship cannot be read from git. Profiles need a
  stable operator identity from somewhere else.
- **Scope conflict.** `adr-artifact-trust.md` defines trust as "not a gate, not a review
  rule, not a quality score, not a maturity model". Weighting by profile moves toward a
  score. That ADR must be amended or superseded explicitly, not worked around.
- **The scanner's evidence.** What the scanner reads: endorsements, lessons, review
  findings, extraction runs. Whether a profile is declared, inferred, or inferred and
  then confirmed by the operator.
- **Effect.** What a profile changes: which findings block, which skills ask for a
  second endorsement. A profile must never become a way to skip a check.
- **Privacy.** A profile is a judgment about a person. The design says where it lives,
  who sees it, and whether it is committed.

## Acceptance criteria

- [ ] A core ADR in `docs/adr/` defines four things: the profile, its identity source,
      the scanner's inputs, and what profiles change. It amends `adr-artifact-trust.md`'s
      scope explicitly.
- [ ] The privacy questions have written answers.
- [ ] Implementation tickets are filed from the ADR. This ticket closes when the ADR is
      accepted.

## Notes

- The ADR may conclude that per-operator weighting is not worth its cost and that the
  functional/technical role split is enough. That is a valid close.
