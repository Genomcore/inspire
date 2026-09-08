---
id: F07-gates
title: "F7 GATES — enforcement the author cannot negotiate with"
created: 2026-08-13
updated: 2026-08-25
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: XL
importance: High
skills: [code]
status: Open
blocked_by: []
related_to: [F06-tdd]
---

## Description

Theme: **enforcement — "a gate the author can lower is not a gate."** The structural half
of the guardrail doctrine. First the gates ADR (D2): do code-side gates become a declared
extension point, or stay core-only? — deliberately resolving the collision with the
current "validators are not an extension point" stance. Then the machinery: external
profile sources so the `inspire-skills` mirror plugs into `inspire-code` as
externally-owned content (its overwrite-on-sync contract is the opposite of the merge
machinery's, so it is resolved, never merged); escape hatches named, justified in place,
and counted with a ceiling that only falls; ratchets for contaminated ground; thresholds
kept out of the author's reach.

## Acceptance criteria

- [ ] Gates ADR merged; D2 decided and its consequences named.
- [ ] External profile source resolves at run time; a sync upstream never conflicts with
      an operator edit.
- [ ] Suppression accounting exists: greppable form, in-place justification, falling
      ceiling.

## Notes

**Amended 2026-08-25 (emanation-loop epic, per its design doc D11):** the epic
(`feat-emanation-loop` → release 0.8.0) ships this focus's **enforcement
tranche**: the `base/agents/` payload class (agent shells = identity +
permission envelope + doctrine pointer), the materialize+harvest worktree
envelope (design D4 — the test freeze is the harvest filter, structural again),
and the security + quality overseers as read-only oracles at each handoff
(design D3). **The gates ADR's D2 question is answered by the additive-only
roster posture:** the shipped overseer pair is non-removable, projects may only
*add* overseers — the ceiling only rises. Remaining on this ticket after the
epic: the external profile source machinery and suppression accounting (AC-2,
AC-3), plus writing the ADR down as an ADR.

The rearchitecture release — moves doctrine from tier-2 prose into tier-1 machinery. Soft
edge: after F06-tdd (prove the cheap checks first); the ADR can be drafted during F06.
Bundles CODE-03..05 core. The runtime/telemetry link (deck link 6) stays on the shelf —
it needs production reach no skill can install.
