# T2 — screens substrate · registration notes

Five insertions into three shared registration points, for the main session to
apply in the wave-close integration commit. Every edit is a literal
find-and-replace; nothing here needs judgement. Branch: `emanation/t02-screens`.

Nothing in this file is required for `bash plugin/base/bin/test/run-tests.sh` to
pass — the fixture runner invokes `{rule}.sh` directly. What registration buys is
`review.sh` (and therefore the pre-commit and pre-PR hooks) actually running
`screen-coherence.sh`, and the roster telling the truth about it.

---

## 1 · `plugin/base/bin/review.sh` — `DEFAULT_RULES`

`screen-coherence.sh` is a tier-2 coherence rule, so it joins the tier-2 block,
after the last domain-shaped coherence rule and before tier 3 begins.

FIND:

```
touched-entity-lifecycle.sh \
field-coverage.sh \
```

REPLACE WITH:

```
touched-entity-lifecycle.sh \
screen-coherence.sh \
field-coverage.sh \
```

## 2 · `plugin/base/bin/README.md` — the count

FIND:

```
The library implements the **quality gate** (per D24 in the SDD V3 reframe addendum): the 12 rule scripts `review.sh` runs, in three severity tiers plus the style checks below them.
```

REPLACE WITH:

```
The library implements the **quality gate** (per D24 in the SDD V3 reframe addendum): the 13 rule scripts `review.sh` runs, in three severity tiers plus the style checks below them.
```

## 3 · `plugin/base/bin/README.md` — the tier-2 heading

FIND:

```
### Tier 2 — Coherence blockers (error from draft+ in `04_domain`; warning in the layers that carry no lifecycle)
```

REPLACE WITH:

```
### Tier 2 — Coherence blockers (error from draft+ in `04_domain`; warning in `03_features` and `01_adr`, which carry no lifecycle; ramping with the screen's own lifecycle in `05_screens`)
```

## 4 · `plugin/base/bin/README.md` — the tier-2 table: one row rewritten, one row added

FIND (the `sections-present.sh` row, one line):

```
| `sections-present.sh` | (5) All mandatory body sections present + non-empty (actions: Purpose / Inputs / Outputs / Entities / Behavior / Errors; entities: Purpose / Rationale / Invariants / Fields / Touched by), in the order their format spec fixes. Also checks the shape of the remaining KB layers: use-case files under `03_features/` (their sections plus the `AC-N:` id format and its within-file uniqueness), ADRs under `01_adr/` (their sections plus `### Breaking changes` under `## Consequences`), and screen files under `05_screens/` (H1, the `**Features:**` and `**Pattern:**` lines, `## Instantiation`). | Header-only sections fail. `## Touched by` is presence-only — consolidation writes it, and a zero-toucher entity legitimately has it empty. Order is checked in `04_domain` only, and ramps with the object's lifecycle. **Everything outside `04_domain` is warning-severity** and the optional screen sections (`## Module-specific deviations`, `## Current prototype`, `## Notes`) are never flagged, present or absent. |
```

REPLACE WITH (two lines — the rewritten row, then the new one):

```
| `sections-present.sh` | (5) All mandatory body sections present + non-empty (actions: Purpose / Inputs / Outputs / Entities / Behavior / Errors; entities: Purpose / Rationale / Invariants / Fields / Touched by), in the order their format spec fixes. Also checks the shape of the remaining KB layers: use-case files under `03_features/` (their sections plus the `AC-N:` id format and its within-file uniqueness), ADRs under `01_adr/` (their sections plus `### Breaking changes` under `## Consequences`), and screen files under `05_screens/` (H1, the `**Features:**` line, a non-empty `## Bindings`, and the retired `## Instantiation` reported as such). | Header-only sections fail. `## Touched by` is presence-only — consolidation writes it, and a zero-toucher entity legitimately has it empty. Order is checked in `04_domain` only, and ramps with the object's lifecycle. **`03_features` and `01_adr` are warning-severity throughout**; screen findings ramp with the screen's own `lifecycle:`, and a screen carrying no frontmatter reads as draft. The optional screen parts (`**Pattern:**`, `**Components:**`, `## Module-specific deviations`, `## Current prototype`, `## Notes`) are never flagged, present or absent. |
| `screen-coherence.sh` | Screen identity (`id` · `module` · `screen` · `lifecycle` present; enum valid; `id` shaped `{module}.{screen}` or `{surface}.{module}.{screen}`; `module:` agreeing with the path; `superseded_by` resolving), keyed bindings (closed subsection set, keys present and unique per subsection, dispatch outcomes naming a declared state/data key or a screen id, states anchored to something declared), and the join with the named layout (each required region that accepts `data` / `dispatch` / `nav` finds such a binding). | Ramps with the screen's own lifecycle. Three exceptions: `duplicate screen id`, `route collision` and `invalid screen lifecycle value` are errors at every state — none can fire on a pre-0.8 file; the authored-route reading is a heuristic and stays a flat warning; the to-extract-component gate is error at `stable` only. Reports the FORM of an outward reference, never its existence — `wikilinks-resolve.sh` owns resolution. |
```

## 5 · `plugin/base/bin/README.md` — the tier-3 `wikilinks-resolve.sh` row

FIND:

```
| `wikilinks-resolve.sh` | (10) Every `[[wikilink]]` in body resolves to an existing file (SDD object id or PDD/ADR basename). | Warning at draft; error at accepted and stable; warning again at superseded. |
```

REPLACE WITH:

```
| `wikilinks-resolve.sh` | (10) Every `[[wikilink]]` in body resolves to an existing file, across `04_domain` **and** `05_screens`. Four routes, in order: SDD object id, screen `id`, then — for a path-shaped target such as `../patterns/list` — its last segment, then a bare basename. | Warning at draft; error at accepted and stable; warning again at superseded. A screen with no frontmatter reads as draft. Screen file names stay positional, so a screen link resolves by id and never by path. |
```

## 6 · `CLAUDE.md` — the `base/bin/` paragraph

FIND:

```
      `SDD_SPEC_ROOT` (defaults to `inspire_kb/04_domain`). `trust.sh` is here as a
```

REPLACE WITH:

```
      `SDD_SPEC_ROOT` (defaults to `inspire_kb/04_domain`); the rules that check the
      other KB layers read `SDD_KB_ROOT` instead, `screen-coherence.sh` among them —
      screen identity, keyed bindings and the screen↔layout join. `trust.sh` is here as a
```

## 7 · `CLAUDE.md` — the `base/kb/` paragraph

FIND:

```
      in a `surfaces:` frontmatter field, where absent means suite-wide; screens
      instead scope *positionally*, splitting to
      `05_screens/{surface}/{module}/{screen}.md` once 2+ UI surfaces exist. The
```

REPLACE WITH:

```
      in a `surfaces:` frontmatter field, where absent means suite-wide; screens
      instead scope *positionally*, splitting to
      `05_screens/{surface}/{module}/{screen}.md` once 2+ UI surfaces exist — while
      their identity does not move with them: a screen carries a write-once
      `id`/`module`/`screen`/`lifecycle` block, declares its own keyed `## Bindings`,
      and derives its route from `module` + `screen`, so a move is free. The
```
