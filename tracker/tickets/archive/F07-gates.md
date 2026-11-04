---
id: F07-gates
title: "F7 GATES — enforcement the author cannot negotiate with"
created: 2026-08-13
updated: 2026-10-30
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: S
importance: High
skills: [code]
status: Open
blocked_by: []
related_to: [F06-tdd, B5-react-skill-from-the-team]
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

- [x] Gates ADR merged; D2 decided and its consequences named. *Answered 2026-10-28,
      no ADR:* see the tracker-pass amendment below.
- [x] External profile source resolves at run time; a sync upstream never conflicts with
      an operator edit. *Dropped 2026-10-28:* see the tracker-pass amendment below.
- [ ] Suppression accounting exists: greppable form, in-place justification, falling
      ceiling.
- [ ] The INSPIRE Factory runs the ratchet before it merges. When
      `.escape-hatches.json` exists, `/inspire-config` writes the ratchet as a check, and
      lists every other check the project's commit hooks run, so code the Factory merges
      never fails the next person's commit. A config test covers a project with a
      ratchet. *Added 2026-10-30:* see the fifth design-review amendment below.

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

**Amended 2026-09-09 (first field run of `/inspire-emanate`, gs project):** one defect
for the suppression-accounting tranche (AC-3). `escape-hatch-ratchet.sh` counts a
**mention**, not only a use — its regex has no use/mention distinction, so a persona that
explained in a doc comment why a suppression was unavailable turned the ratchet red at
1/0 on that sentence. It reworded rather than raising a ceiling, correctly. The
consequence is that no file under a scoped directory can document why a hatch was
avoided, which is perverse for a gate whose purpose is making hatches justified in place.
Fold into AC-3's "in-place justification": the counted form must be distinguishable from
prose that names it.

The rearchitecture release — moves doctrine from tier-2 prose into tier-1 machinery. Soft
edge: after F06-tdd (prove the cheap checks first); the ADR can be drafted during F06.
Bundles CODE-03..05 core. The runtime/telemetry link (deck link 6) stays on the shelf —
it needs production reach no skill can install.

**Amended 2026-10-28 (tracker pass): narrowed to the ratchet, XL → S.**

- *AC-1, the gates question.* It has an answer on both sides. Attended, the shipped
  overseer pair is non-removable and a project may only add overseers (the 0.8.0
  amendment above). Unattended, the INSPIRE Factory runs every gate of a run, and a
  project declares its own checks as the phases of its `.inspire/emanate.yml`. Code-side
  gates are a declared extension point there, and no ADR in this repository is left to
  write.
- *AC-2, the external profile source.* Who owns stack profiles is moving: the Factory's
  work in progress reads profiles from the project's own skills. An external source in
  `inspire-code` has no settled consumer, so the criterion is dropped. It is refiled
  once profile ownership settles, if a mirror still needs to plug in.
- *AC-3 stays.* `escape-hatch-ratchet.sh` already counts suppressions against a ceiling
  from `.escape-hatches.json` that only moves down, and the pre-commit and pre-PR hooks
  run it. What remains is the 2026-09-09 defect: the counted form must be
  distinguishable from prose that names it.

**Amended 2026-10-30 (fifth design-review session): the ratchet runs in the Factory too.**

- *Decision:* quality gates are implemented as minimum thresholds the code must meet,
  checked automatically. Code the INSPIRE Factory merges must never be rejected by the
  next person's commit.
- *The case:* a Factory unit merged code with a cast. The ratchet is gate 1 of INSPIRE's
  pre-commit hook, but `/inspire-config` builds the Factory's checks (the phases of
  `.inspire/emanate.yml`) from the stack skills' commands only, and the ratchet is not
  one of them. The Factory's post-run analysis notices escape hatches only after the
  merge. So the next commit made by a person failed the ratchet on code it never
  touched.
- *Change:* the new criterion above. `/inspire-config` writes the ratchet as a check
  whenever `.escape-hatches.json` exists, and its question on which commands block a
  unit lists every other check the project's commit hooks run (husky, lefthook or a
  hand-written hook).
- *Factory design:* the INSPIRE Factory's control-plane design already removes the
  direct merge (a run delivers branches and checks every toolchain before delivering)
  and runs every check entry of a toolchain for every unit, lint included. It does not
  say Config writes the ratchet as one of those entries. The criterion holds for
  `emanate.yml` today and for the spec config once that design ships.
- No Factory port: the check is declared in the project's own config, and the Factory
  runs whatever is declared there.
