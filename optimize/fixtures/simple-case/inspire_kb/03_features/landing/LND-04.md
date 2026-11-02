---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# LND-04: Meet CORA

> Source: [[../../02_modules/landing]]

CORA is the differentiator, so it has its own section. The visitor reads the claim
that the assistant administers the platform instead of only explaining it, sees
three short demos triggered by a sentence the user types, and reads the closing line
on the three server-side security levels.

**State:** 🟡 Planned
**Priority:** Core
**Depends on:** [[LND-02]]

## Actor
A clinical data lead or security officer who distrusts "copilot" demos.

## Preconditions
- `P1` — Three demo recordings exist, one per prompt.

## Main flow
1. `B1` — The visitor reads the section headline stating that CORA administers the
   platform rather than only explaining it.
2. `B2` — The visitor sees three demo cards, each showing the prompt a user types and
   a looping recording of the result.
3. `B3` — The visitor reads the closing sentence: three security levels evaluated
   in server, App scope, user role and index partition, and CORA never sees what the
   user would not see.

## Alternative flows
### AF-1: Reduced motion
The visitor has reduced motion enabled. Recordings do not autoplay and show a poster
frame with a play control.

## Error flows
### EF-1: Recording fails to load
The card keeps the prompt text and shows the poster frame; the page reports no
broken media.

## Postconditions
- `Q1` — The visitor has seen the three prompts and the security closing line.

## Acceptance criteria
- [ ] AC-1: The section renders exactly three demo cards.
- [ ] AC-7: The three prompts read, verbatim: "Which collections have patients with a BRCA1 variant and no generated report?", "Run the annotation pipeline on the 40 new exomes and notify me on Slack." and "Onboard Dr. Puig in the Oncology OU with read permission."
- [ ] AC-2: Each demo card contains a media element with a poster image and a text alternative describing the outcome.
- [ ] AC-3: With `prefers-reduced-motion: reduce`, no recording autoplays and each card shows a play control.
- [ ] AC-4: When a recording fails to load, the card still shows the prompt and the poster and the browser console logs no unhandled media error.
- [ ] AC-5: The closing sentence names the three levels "App scope", "user role" and "index partition" and states that the server evaluates them.
- [ ] AC-6: Every accent inside the CORA section uses the violet token; the teal token appears nowhere in the section.
