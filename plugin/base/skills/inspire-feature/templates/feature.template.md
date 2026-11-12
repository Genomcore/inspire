---
# faces: [face-a]       # blast radius: the face ids this use case affects
# bundles: [bundle-a]   # blast radius: the bundle ids it affects
# omit both = the whole project; see `.claude/skills/_references/face-scope.md`
---

# {FEATURE-ID}: {Feature Name}

> Source: [{module}](../{module}.module.md)

{One-paragraph description of the feature.}

**State:** 🟡 Planned
<!-- State ladder: 🟡 Planned → 🔵 In progress → 🟢 Implemented. -->
**Priority:** {Core | Important | Nice-to-have}
**Depends on:** [{feature-id}]({feature-id}.feature.md), [{feature-id}]({feature-id}.feature.md)
<!-- omit the Depends on line entirely when there are no dependencies -->

## UC1: Actor
{Primary persona}

## UC2: Preconditions
- `P1` — {what must be true before this flow starts}
- `P2` — {a second precondition, or delete this line}

<!--
  Keyed entries, per `.claude/skills/_references/keyed-heads.md`: keys are write-once,
  never renumbered, never reused, and gaps are legal. A machine-readable head from the V3
  vocabulary — actor(role) · exists(module.entity) · absent(module.entity) ·
  state(module.entity, value) — may precede the prose where one fits exactly:
  `- `P1` — actor(admin) — {prose}`. Most use-case preconditions are prose-only, which is
  correct: a use case describes WHAT from the user's perspective. Nothing to state at all
  is written as the single line `None.`
-->

## UC3: Main flow
1. `B1` — {Step 1}
2. `B2` — {Step 2}

<!--
  Every step is keyed. The markdown ordinal is presentation; the `Bn` key is the step's
  identity, so deleting a step leaves a gap rather than renumbering the survivors.
-->

## UC4: Alternative flows
### AF-1: {Description}

## UC5: Error flows
### EF-1: {Description}

## UC6: Postconditions
- `Q1` — {what is true after successful completion}

<!--
  Same keyed shape. V4 heads where one fits — created(module.entity) ·
  updated(module.entity) · deleted(module.entity) · unchanged(module.entity) ·
  returns(field) — prose-only otherwise.
-->

## UC7: Acceptance criteria
<!-- ids are stable: never renumber; a new criterion takes the next free id; never reuse a deleted id; gaps are legal -->
- [ ] AC-1: {Testable criterion 1}
- [ ] AC-2: {Testable criterion 2}
