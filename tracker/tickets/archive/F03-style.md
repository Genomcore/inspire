---
id: F03-style
title: "F3 STYLE — one prose contract for every artifact"
created: 2026-08-13
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: roadmap
size: M
importance: High
skills: [domain, feature, adr, screens, module, bootstrap]
status: Done
blocked_by: [F02-contracts]
related_to: []
---

## Description

Theme: **voice — how each artifact is written.** Ship the ASD-STE100-derived writing
contract as `_references/writing-style.md`: active voice with a named actor, one
instruction per sentence, bounded noun chains, one concept one word, short paragraphs —
bound by section kind (normative / explanatory / tabular) so trade-off prose keeps its
clauses. Consolidate the six-plus scattered de-facto style rules into it, seed
`00_bootstrap/glossary.md`, thread the binding table into the six authoring skills, and
ship the `prose-style` validator on the lifecycle ramp (warn at draft, error at accepted+),
scoped per layer with exemption lists.

## Acceptance criteria

- [x] `writing-style.md` shipped; the scattered rules deleted from their six+ locations. —
      `plugin/base/skills/_references/writing-style.md` (`d288776`).
- [x] Six authoring skills reference the contract; glossary seeded and wired to R4. —
      glossary seed + bootstrap review check in `0a0ed98`.
- [x] `prose-style` validator on the ramp; historical-language rule scoped so ADR
      supersession sections are exempt. — `bin/prose-style.sh` (`a1cd70f`): ramp at
      `:551` (draft → warning, accepted/stable → error, superseded → warning), R1/R3 flat
      warnings at `:592` because they are heuristics.

## Notes

Hard dependency: the validator binds to sections F02-contracts pins. The contract prose
alone could ship earlier, but the focus's claim includes enforcement. Bundles
STYLE-01..04. Source proposal: `../../sandbox/docs/writing-style.md`.

Spike + surface joined the contract's lists; the proposed riders were rejected;
enforcement is en-only by declared scope. R2 = 25 words/sentence and R5 = 6
sentences/paragraph confirmed (ASD-STE100's own numbers; shipped-KB calibration:
179 prose sentences, 17 over the cap, zero paragraphs over 6). The 250-vs-300
threshold question (Q9) stays deferred. Cross-ref ticket 070-glossary-population.

## Closing note (2026-08-19)

Shipped in **0.7.0** (PR #14, merge `21f3fd8`, tag `v0.7.0`). Verified against the tree at
close, not against the release notes.

**Three residuals, all with a home — none is orphaned by this closure:**

- Nothing populates the glossary the contract's R4 reads → [[070-glossary-population]].
- The validator's known nits (`cannot` missing from the stopword list; R4 reporting the
  glossary's spelling; a synonym containing `.` or `::` never matching) →
  [[070-carryforwards]].
- Q9, the deferred 250-vs-300 threshold, moved to [[070-carryforwards]] as a bullet so it
  survives this archive. Its underlying context was **not** recoverable from the repo at
  close — the number appears nowhere in `prose-style.sh`, `writing-style.md`, the source
  proposal or the clarity map. The bullet records the question verbatim and says so.
