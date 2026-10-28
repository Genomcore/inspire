---
id: F04-mech
title: "F4 MECH — move mechanical work from prose to scripts"
created: 2026-08-13
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: L
importance: High
skills: [task, lesson, workspace, surface]
status: Open
blocked_by: []
related_to: [F05-restruct]
---

## Description

Theme: **placement — judgment for agents, mechanics for machines.** Apply "the cheapest
layer that can enforce a rule owns it" to INSPIRE itself. KB-wide structural validator
family (junk files, rename sweeps, historical language, screens-tree shape, roster and
tracker invariants — the index-coherence class died with F01 in 0.7.0 and is never
scripted); script the tracker and lesson mechanics (ID generation, status→location moves,
filters, frontmatter stamping); move the workspace review's counting phases to a script
and re-pin the report skeletons to its output.

Pre-work: split the oversized scripts — a list every release since 0.7.0 has made longer.
Re-measured 2026-10-28 at 0.12.1: `materialize.sh` **1209** · `_lib.sh` **970** ·
`prose-style.sh` **866** · `_keyed-heads.sh` **628** · `screen-coherence.sh` **628** ·
`scripts/lib/merge.sh` **599** · `emanate-harvest.sh` **589** · `trust.sh` **564** ·
`sections-present.sh` **510**.

## Acceptance criteria

- [ ] Each scripted check is deleted from the prose that stated it (no copy N+1).
- [ ] Tracker and lesson mechanics run as scripts; skills call them.
- [ ] Workspace Phases 5–6 numbers come from a script; report skeletons consume them.
- [ ] No shipped script exceeds ~500 LOC — nine offenders at 0.12.1, five at 0.7.0,
      three when this ticket was written.
- [ ] **Five `prose-style.sh` items cleared while that script is open.** R3's stopword
      list is missing `cannot`, so "the auth subsystem cannot delegate" reads as a noun
      run — one word. R3 also flags `None beyond Fields constraints.`, the one-line
      `## Invariants` body that `format-entity.md` and `entity.md.template` prescribe for
      an entity with no invariants, so every such entity carries a warning its author
      cannot clear without departing from the format — exempt the line or reword it in
      both homes. R4 names the glossary's spelling in the finding rather than the
      artifact's, pointing the author at the wrong token. R4 synonyms containing `.` or
      `::` can never match, because the id-stripper eats them before comparison
      (commented in-script) — fix the stripper or state the restriction in the contract.
      And Q9, below.
- [x] **Q9 decided or cancelled.** F03-style recorded only "the 250-vs-300 threshold
      question (Q9) stays deferred", and at F03's close neither number appeared in
      `prose-style.sh`, `writing-style.md`, the source proposal or the clarity map.
      Reconstruct what the two numbers measured — and **cancel the item outright if the
      answer is that the shipped R2 (25 words/sentence) and R5 (6 sentences/paragraph)
      caps already settled it**, which is the likeliest reading.
      *Cancelled 2026-10-28:* the shipped caps settle it. `prose-style.sh` caps R2 at 35
      words per sentence and R5 at 8 sentences per paragraph, and neither 250 nor 300
      appears in `prose-style.sh` or `writing-style.md`.

## Notes

Hard dependency on F02-contracts: validators enforce pinned shapes — **discharged**, F02
shipped in 0.7.0 and is archived, so `blocked_by` is now empty and this is the head of the
spine. Excludes the monolith-skill split — that is F05-restruct, shipped in 0.7.0.
Bundles CTX-01..03 + SPLIT-01/02.

F05 shipped first (bundled into 0.7.0) — F04 now operates on the split-skill layout
(entry + references/), shrinking its future diffs.

Severity-grammar unification descoped from F05 to here (enum change; `verify`
untranslatable).

**Absorbed `070-prose-style-nits` (2026-08-19).** Those four items are not their own
release: `prose-style.sh` is 812 LOC and named in this ticket's own pre-work for
splitting, and nobody splits an 812-line script without opening R3 and R4. They ride the
split or they never happen. None of them blocks it — the first three change findings,
never the ramp — so the split can ship alone if the window closes early.

**Synthesizer completeness instrumentation** (routed here 2026-08-19 from the cancelled
`070-carryforwards`): `review.workflow.mjs`'s check definitions are fetch-dependent — the
synthesizer must read `workspace-review.md` — with no instrumentation proving it did.
Candidate: a synthesizer schema with a required `phases_performed: string[]`. Declined for
0.7.0 because the mjs surface was frozen; it belongs here because AC-3 above already
re-pins the workspace report skeletons to script output, and a phase the synthesizer
silently skipped is exactly the failure that AC is meant to make visible.
(`plugin/base/skills/inspire-workspace/review.workflow.mjs`.)

Two deferrals recorded: review.sh's silent skip of non-executable rule scripts
(`review.sh:52-54` — a missing +x warns to stderr and continues rather than failing
the review); trust.sh's unreachable `surfaces.md` branch (`trust.sh:181` maps
`00_bootstrap/surfaces.md` to the `surface` owner, but `scan_paths()` at
`trust.sh:224-235` never walks that path — the case arm is dead code).

**Amended 2026-10-28 (tracker pass): hold the split until emanation leaves.** Emanation
is moving to the INSPIRE Factory. When the in-repo loop leaves, `emanate-harvest.sh`, the
`plan-*` and `gate-*` units and the `derive-*` units leave with it, and `_lib.sh` and
`materialize.sh` lose the code that serves them. Splitting those scripts first splits
code that is about to go. The prose-style items, the tracker and lesson scripts and the
workspace counting phases do not wait.
