---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# LND-02: Understand the problem and the pillars

> Source: [[../../02_modules/landing]]

Below the hero the visitor reads why OpenBIMS exists and what it stands on. The
"Why" section states three pains in one sentence each: data silos, vendor lock-in
with data-residency limits, and AI that answers but does not operate. Four pillar
cards then answer them: sovereignty, real open source, operational AI, API-first.

**State:** 🟡 Planned
**Priority:** Core
**Depends on:** [[LND-01]]

## Actor
A decision maker at a hospital or research centre evaluating whether to install.

## Preconditions
None.

## Main flow
1. `B1` — The visitor scrolls past the hero and reads the three pains: silos,
   lock-in, showcase AI.
2. `B2` — The visitor reads the four pillar cards, each with a title and one
   supporting sentence.
3. `B3` — The visitor recognises the AI pillar by its violet accent, distinct from
   the teal used elsewhere.

## Alternative flows
None.

## Error flows
None.

## Postconditions
- `Q1` — The visitor can name the three pains and the four pillars.

## Acceptance criteria
- [ ] AC-1: The "Why" section renders exactly three pain items, titled "Silos", "Lock-in" and "Showcase AI", each with one supporting sentence.
- [ ] AC-2: The pillars section renders exactly four cards titled "Your data, your infrastructure", "AGPL-3.0, not open-washing", "CORA sees everything and does everything" and "Everything is an action".
- [ ] AC-3: The sovereignty card states that the database of the platform stores metadata only and clinical data stays in the visitor's external data sources.
- [ ] AC-4: The open-source card states that Community, Cloud and Enterprise run the same core and that the CLI and SDK are Apache-2.0.
- [ ] AC-5: The CORA card uses the violet accent token and the other three cards use the neutral or teal tokens.
- [ ] AC-6: On a 375 px wide viewport the four cards stack in one column with no horizontal scroll.
