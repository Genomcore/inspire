---
id: F12-guide
title: "F12 GUIDE — INSPIRE explains itself"
created: 2026-08-13
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-10-28
epic: roadmap
size: S
importance: Mid
skills: []
status: Cancelled
blocked_by: []
related_to: [F13-viz]
---

## Description

Theme: **self-description.** A new read-only concierge skill (housekeeping family) inside
governed projects. Methodology questions ("spike or prototype?", "what does `draft`
mean?") route to the one owning document per topic; project-state questions ("which ADRs
are still design-only?", "what surfaces do we have?") answer from the KB. Answers stamp
the installed version from `.inspire.lock` and flag skew against the documented latest.
First ticket is D7: content source — pure router over installed skills + READMEs (default;
avoids copy N+1 and version skew), bundled condensed handbook, or live-site links for
depth.

## Acceptance criteria

- [ ] D7 decided; the skill routes rather than restates — no rule text duplicated from an
      owning document.
- [ ] Project-state answers read the KB live; methodology answers cite their source file.
- [ ] Every answer carries the installed version; skew against latest is flagged.

## Notes

Free lane, rider-sized — fits any release window; temperamentally pairs with the contract
wave. New skill: touches the manifest and the hardcoded-count test — **the same fixed cost
[[F13-viz]] pays**, so scheduling the two in one window pays it once. They are not merged:
a concierge router and a deliverables renderer share nothing but that overhead, and one
ticket covering both would describe neither. `skills: []` because
the enum predates it — the work creates the skill it would name. Bundles GUIDE-01..03.

## Cancelled 2026-10-28 — no defect behind it (rule 2)

The ticket names nothing broken. It was filed as a rider for any window and rode none of
the releases from 0.7.0 to 0.12.1. Its first criterion, D7 (route, bundle or link), is a
question rather than a deliverable. The shared new-skill cost it counted on goes with
[[F13-viz]], cancelled on the same day.

The training of new INSPIRE operators is the likeliest source of a real case. Refile when
an operator asks a methodology or project-state question and the runtime gives a wrong
answer or none. That case also settles D7: it shows whether the operator lacked a router
or lacked the content.
