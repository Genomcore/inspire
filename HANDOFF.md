# T2 — screens substrate · usage-limit checkpoint

Tree is **clean and green** at `1e22c0e`: `bash plugin/base/bin/test/run-tests.sh`
= **127 total / 0 failed** (baseline was 107 / 0).

## Done (committed)

- **Skill + templates** — `plugin/base/skills/inspire-screens/`:
  `SKILL.md` (3 tiers with sibling middle, three ownerships, screen-file
  structure, Rules 2/5/6/7 rewritten, `promote` + `routes` invocations),
  `templates/screen.md.template` (identity block · H1 · Features ·
  optional Pattern/Components · `## Bindings` with Data/Dispatches/Navigation/
  States), `templates/pattern-entry.md.template` (`## Regions` with
  `Fill`/`Accepts`), new `references/format-screen.md` (canonical shape,
  identity, route derivation, claims, join, **old-shape → new-shape catalogue**
  = T4's refusal list), new `references/screen-lifecycle.md`, new
  `references/screen-routes.md`, plus `screen-create.md`, `screen-checks.md`,
  `screen-validate.md`, `screen-catalog.md`, `screen-propagation.md`.
- **Shared references** — `_references/surface-scope.md` (path↔route → derived
  route), `_references/lifecycle-rules.md` (screens join the enum; new
  `### Screens` tier table; prose-style claim retired), `_references/findings-format.md`
  (new `screen-coherence` rule id + full finding-type catalogue).
- **KB** — `base/kb/05_screens/README.md` (three ownerships, what a screen
  carries), `patterns/list.md` + `patterns/detail.md` region-shaped
  (`columns` slot gone).
- **Validators** — new `base/bin/screen-coherence.sh`; `sections-present.sh`
  screen block (Bindings required, retired `## Instantiation`, lifecycle ramp);
  `wikilinks-resolve.sh` (screen-id index, screen-layer reach, path-shaped
  target read by last segment, `$SDD_KB_ROOT` fix).
- **Fixtures** — 20 new, 8 migrated, 1 rescoped rename
  (`wikilinks-resolve/kb-root-scope-silent` → `kb-root-scope-screens-only`).
- **Beyond brief (flagged):** one stale claim in
  `base/skills/inspire-module/references/module-review.md` retired.
- **Non-vacuity probes run** (stub-the-mechanism, on the working file, restored
  after): screen-id index · path last-segment · screen reach · retired-section ·
  pattern join · duplicate id · route collision · screen severity ramp — **all
  8 confirmed load-bearing** (each stub makes its fixture FAIL).

## In progress — nothing half-written

No file is left mid-edit. Working tree clean; every suite claim above measured.

## Next steps (only these remain)

1. **`REGISTRATION.md` at the worktree root** — not yet written. Exact content
   to ship (drafted, not committed):
   - `plugin/base/bin/review.sh` `DEFAULT_RULES`: insert
     `screen-coherence.sh \` between `touched-entity-lifecycle.sh \` and
     `field-coverage.sh \` (tier-2 coherence block).
   - `plugin/base/bin/README.md` tier-2 table: new row for
     `screen-coherence.sh`; and its `sections-present.sh` row's screen clause
     (`H1, the **Features:** and **Pattern:** lines, ## Instantiation`) →
     (`H1, the **Features:** line, non-empty ## Bindings`) plus "screens ramp
     with their own lifecycle"; and the `wikilinks-resolve.sh` row → "checks
     `04_domain` **and** `05_screens`; resolves SDD ids, screen ids, then
     basenames".
   - `CLAUDE.md`: the `05_screens` KB paragraph gains the screen identity
     block + bindings; the validators paragraph gains `screen-coherence.sh`.
2. Re-run `bash plugin/base/bin/test/run-tests.sh` (expect 127/0) and report.

## Decisions fixed in-package (for the plan doc)

- **Id rendering:** frontmatter `id`/`module`/`screen`/`lifecycle`; legal id
  shapes exactly `{module}.{screen}` or `{surface}.{module}.{screen}` checked
  against the file's *own* declared fields; `module:` must match the path's
  module dir; `screen:` deliberately **not** tied to the filename (a rename is
  a move).
- **Route map:** routes are never authored — no route in the H1, no `## Route`
  section; `/inspire_screens routes` renders map + transition graph, writes
  nothing; `route collision` = same `module`+`screen` in one shell.
- **Bindings:** closed subsection set Data · Dispatches · Navigation · States
  (Navigation added because A12 lists a `{id}/nav/{key}` claim family);
  outcome grammar `→ [[id]]` | ``state `k` `` | ``refresh `k` ``; pipe-syntax
  wikilinks in table cells escape their pipe (`\|`), bare colon form also
  accepted.
- **Join-check:** pattern regions declare `Fill` (required|optional) +
  `Accepts` (data|dispatch|nav|static); a required region accepting a binding
  kind with no such binding is a finding. A pattern with no `## Regions` is one
  warning **on the pattern file**, deduped per pattern.
- **Severity:** screen findings ramp with the screen's own lifecycle (no
  frontmatter ⇒ draft ⇒ warning, so nothing pre-0.8 blocks); `duplicate id`,
  `route collision` and `invalid lifecycle value` are errors at every state;
  `authored route` is a flat warning (heuristic); the to-extract-component gate
  is error at `stable` only. `prose-style` stays flat for screens, by decision.
- **`wikilinks-resolve` reach:** it iterates screens — otherwise the screen-id
  index would be dead code. Path-shaped targets resolve by last segment (the
  exact-path variant was dropped as unfalsifiable).
- **Fixture decoys kept old-shape on purpose:** the nine
  `*/kb-root-scope-silent` trees plus `sections-present/scope-*` keep
  domain-shaped decoy screens — migrating them would weaken the leak bait.
  Those are the **mixed-kind trees whose domain side is T1's**; no screen-side
  migration is owed there.

## Open questions

None blocking.
