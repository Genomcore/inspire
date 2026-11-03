---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# LND-06: Resolve objections

> Source: [[../../02_modules/landing]]

The visitor reads the four objections the brief anticipates and their answers:
what AGPL obliges, where clinical data lives, what happens if Genomcore disappears,
and whether the platform is certified. The certification answer makes no claim the
vault does not verify: it states that MDR/IVDR/CE conformity is part of the
Enterprise offer, not an achieved fact.

**State:** 🟡 Planned
**Priority:** Important
**Depends on:** [[LND-05]]

## Actor
A hospital legal or compliance officer, or a CTO assessing vendor risk.

## Preconditions
None.

## Main flow
1. `B1` — The visitor reads four collapsed questions.
2. `B2` — The visitor expands a question and reads its answer.
3. `B3` — The visitor expands another question; the first stays as the visitor
   left it.

## Alternative flows
### AF-1: Deep link
The visitor arrives with a URL fragment naming one question. That question renders
expanded and scrolled into view.

## Error flows
None.

## Postconditions
- `Q1` — The visitor has read the answer to at least one objection.

## Acceptance criteria
- [ ] AC-1: The section renders exactly four questions: "Does AGPL force me to publish my code?", "Where is my clinical data?", "What if Genomcore disappears?" and "Is it certified?".
- [ ] AC-2: The AGPL answer states that the obligation applies only to an organisation that modifies OpenBIMS and offers it as a service to third parties.
- [ ] AC-7: The AGPL answer states that internal use carries no publication obligation.
- [ ] AC-8: The AGPL answer states that a commercial licence exists for embedding OpenBIMS in a proprietary product.
- [ ] AC-3: The certification answer states that MDR/IVDR/CE conformity is part of the Enterprise offer and makes no present-tense claim of certification, CE marking or MDR compliance.
- [ ] AC-4: Expanding one question does not change the expanded state of the others.
- [ ] AC-5: Each question is a button with `aria-expanded` reflecting its state and is operable with Enter and Space.
- [ ] AC-6: A URL fragment matching a question's id renders that question expanded on load.
