---
id: 090-change-scoped-test-runs
title: "090 — the inner loop runs the whole estate: scope a run to what the change touches"
created: 2026-09-08
updated: 2026-09-08
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Medium
skills: []
status: Open
blocked_by: []
related_to: []
---

## Description

`bash plugin/test/run.sh` is the only entry point, and it runs all 1241 assertions every
time. It is invoked two or three times per change during development, so the cost is not
the run — it is the multiple. Measured on a 12-core machine after the 0.9.2 performance
pass (329 s → 247 s wall, 1112 → 961 CPU-seconds): a full run is ~250 s, so a single
change costs 8–12 minutes of waiting before anything about it is known.

**The wall cannot be fixed by making the estate faster.** That was measured rather than
assumed:

- Slot utilisation is already 89–95%; the scheduler has nothing left to give.
- `-j 12` is *slower* than `-j 8` (258 s vs 241 s) — the run is kernel-bound on
  `fork`/`exec`, not CPU-bound, so more concurrency costs more than it buys.
- The run is therefore **work-bound**: wall ≈ total job-seconds ÷ 8, and total work is
  ~1900 job-seconds. Halving the wall means removing half the work.

Removing that work is not available cheaply. The remaining candidates were priced and all
are small or unsafe: eliminating *every* `awk` fork in the estate (58,176 of them) is a
15–21% ceiling and ~21 s in practice, behind a rewrite of the fence tracker every
validator depends on; sharing `emanate-derive`'s sweep across a plan run is ~7 s and needs
a cache that could let derive report "clean" for a tree it never checked. The four biggest
costs — `golden/emanate-plan` (559 script runs), `test-plan-lib.sh` (418),
`golden/emanate-derive` (312) and 72 `materialize.sh` invocations — are integration tests
that re-run the real tool chain end to end. That is the design, not a defect.

What *is* available is that a given change never needs the whole estate. Standalone costs:

| `run.sh <filter>` | wall | assertions |
|---|---|---|
| `manifest` | 19 s | 39 |
| `materialize` | 49 s | 267 |
| `upgrade` | 129 s | 412 |
| `golden` | 236 s | 433 |

A change under `plugin/scripts/` cannot affect a validator's golden fixtures; a change to
one validator cannot affect the upgrade chain. The filters to exploit that already exist
and are used by hand — this ticket is about the harness knowing the mapping so the operator
does not have to remember it.

## Acceptance criteria

- [ ] `run.sh` grows a way to scope a run to the areas a working-tree diff touches, and
      the mapping from path to area lives in **one** place that a reader can check against
      the tree (a table in `run.sh` or beside it, not scattered across call sites).
- [ ] The mapping is **conservative by construction**: a path it does not recognise runs
      everything, so a new directory can never silently narrow a run. A test asserts that
      an unmapped path selects the full estate.
- [ ] Scoping never changes a verdict: for at least one change per area, the scoped run's
      `--inventory` output is a strict subset of the full run's, with identical
      PASS/FAIL/SKIP lines for every job it selected.
- [ ] The full estate stays the default and the pre-PR gate. Nothing about
      `.claude/hooks/template-runtime-version.sh` or the release checklist starts depending
      on a scoped run.
- [ ] Measured on a real change per area, recorded in the PR body: what the scoped run
      selected, its wall, and the full run's wall for comparison.
- [ ] **Or the ticket closes Done with zero code changed**, if the honest finding is that
      the existing bare-word filters are enough and only the convention needed writing
      down — in which case `CLAUDE.md` gains the path→area table as guidance and that is
      the whole deliverable.

## Notes

Filed alongside PR #18, the performance pass that took the estate from 329 s to 247 s
(−25%) and −151 CPU-seconds by removing ~45,000 process spawns: three forks
per iteration in `run-tests.sh`'s fixture loop that ran *before* the filter (~32,000), four
`dirname` calls at every `_lib.sh` source (~10,000), and `_apply_write`'s six spawns per
file down to two or three. That pass also sharded the two longest golden suites, which is
what makes per-area filtering worth automating: the shard names carry the rule
(`golden/emanate-plan#3`), so a filter naming the rule still selects all of its shards.

Two things deliberately **not** in this ticket, under the one-theme rule:

- Splitting the hand-wired siblings (`test-plan-lib.sh` is 53 s solo, 418 script runs, and
  counts as a single run-level assertion, so its cost is invisible in the totals). That is
  a coverage-visibility question, not a scoping one.
- The `awk` and `classify` rewrites priced above. Both are performance work on
  safety-critical parsing and should be judged on their own merits, if ever.

Measurement caveat worth carrying: at this granularity the numbers are noisy — the same
job measured 216 s and 106 s in two runs at the same `-j`. CLAUDE.md's standing warning
applies, and any figure in this ticket is a single-run observation on one machine.
