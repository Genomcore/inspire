---
id: 070-glossary-population
title: "070 — nothing writes 00_bootstrap/glossary.md in 0.7"
created: 2026-08-18
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: follow-up
size: M
importance: Mid
skills: [bootstrap, domain]
status: Done
blocked_by: []
related_to: [F03-style, 070-format-doc-consolidation, 070-ladder-unification]
---

## Description

The `00_bootstrap/glossary.md` seed ships empty in 0.7.0, and the writing-style
contract's R4 (one concept, one word) reads it — but nothing populates it. Rows are
only meant to land via `inspire-bootstrap`'s ownership, when an interview settles a
naming question. No flow currently drives that population.

## Acceptance criteria

- [ ] Design doc: where does a glossary row get proposed from (bootstrap interview,
      domain interview, both), and what does `inspire-bootstrap` do with a candidate
      term.
- [ ] A population flow ships, **or** the empty-seed-plus-manual-editing status quo is
      explicitly ratified as sufficient — ratification closes this Done with zero code
      changed. Both outcomes are real answers; the ticket is not obliged to produce code.

## Notes

Future work — recorded, not invented, at the 0.7.0 close. Cross-ref F03-style (owns
R4 and the writing-style contract that reads the glossary).

**One of the three unfinished pieces of the contract wave.** F02-contracts and F03-style
shipped in 0.7.0 and are archived; what they deferred lives on as
[[070-format-doc-consolidation]] (one artifact shape, two files),
[[070-glossary-population]] (a contract rule reads a file nothing writes) and
[[070-ladder-unification]] (four maturity vocabularies). Separate work, one origin — read
the other two before scoping this one.

Worth recording while this is open: R4 degrades cleanly to a no-op on an empty glossary
(`prose-style.sh:655` binds an empty term list), so the runtime ships a rule that
*cannot fire in any project*. Inert rather than noisy — the good version of the problem
— but a shipped rule with no data source is a standing untruth about what the contract
enforces, and that is the argument for the Mid importance.

## Closed 2026-08-19 — status quo ratified

**Answered, not abandoned.** The empty seed plus manual authoring is sufficient. The
glossary is product content, and INSPIRE's contract for product content is to ship a
skeleton and let the skills author into it — the same deal every other KB file gets.
`inspire-bootstrap` already owns the file and already has the trigger (an interview that
settles a naming question); nothing further needs designing.

Nothing is broken while this stays as it is: R4 degrades cleanly to a no-op on an empty
glossary (`prose-style.sh:655` binds an empty term list). The rule is complete — a hand-
written row makes it fire immediately. What was missing was never machinery, only an
automated population flow that was never promised.

This is the second acceptance criterion above, taken: "…or the empty-seed-plus-manual-
editing status quo is explicitly ratified as sufficient." Reopen if a real project fills
a glossary by hand and finds the flow wanting — that is evidence; a design question in
the abstract is not.
