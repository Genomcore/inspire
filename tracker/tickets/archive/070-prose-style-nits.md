---
id: 070-prose-style-nits
title: "070 — prose-style validator nits, one sitting"
created: 2026-08-19
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: follow-up
size: S
importance: Low
skills: []
status: Cancelled
blocked_by: []
related_to: [070-glossary-population]
---

## Description

Four small items against `plugin/base/bin/prose-style.sh` and the contract it enforces,
all surfaced at the 0.7.0 close and grouped here because they are one file and one
sitting. Routed out of `070-carryforwards` (cancelled 2026-08-19) so they are visible
rather than buried in a nine-bullet bag.

## Acceptance criteria

- [ ] **R3 stopword gap.** `cannot` is missing from the stopword list, so "the auth
      subsystem cannot delegate" reads as a noun run. One-word fix.
- [ ] **R4 reports the wrong spelling.** The finding names the glossary's spelling rather
      than the artifact's. Cosmetic, but it points the author at the wrong token.
- [ ] **R4 synonyms containing `.` or `::` can never match** — the id-stripper eats them
      before comparison. Commented in-script today; decide whether to fix the stripper or
      to document the restriction in the contract.
- [ ] **Q9 — the 250-vs-300 threshold.** Decided or cancelled (see below).

## Notes

**Q9's context did not survive.** F03-style recorded only "the 250-vs-300 threshold
question (Q9) stays deferred". At F03's close neither number appeared in
`bin/prose-style.sh`, `_references/writing-style.md`, the source proposal
(`../../sandbox/docs/writing-style.md`) nor the clarity map. Whoever picks this up starts
by reconstructing what the two numbers measured. **Cancel the item outright if the answer
is that the shipped R2 (25 words/sentence) and R5 (6 sentences/paragraph) caps already
settled it** — that is the likeliest reading, since those are the only calibrated
thresholds the contract ships.

The first three are safe any time; they change findings, never the ramp. Cross-ref
[[070-glossary-population]] — R4's usefulness depends on a glossary that has rows in it,
so fixing R4's spelling report before anything populates the glossary is polish on an
unreached path.

## Cancelled 2026-08-19 — absorbed into F04-mech

Not cancelled as "won't do" — **cancelled as "not its own ticket."** `prose-style.sh` is
812 LOC and is named in F04-mech's own pre-work for splitting; nobody opens that file to
split it and leaves four known defects in place. All four items, Q9 included, now live as
acceptance criteria on [[F04-mech]]. This ticket existed for one day, as the staging post
that made the items visible when `070-carryforwards` was broken up.
