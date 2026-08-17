# `.inspire/bin/` — SDD Validation Library

Source of truth for what "review" means in the SDD layer. Shell scripts that
read filesystem state under `inspire_kb/04_domain/`, parse `.md` frontmatter, evaluate
rules, and emit structured findings.

Two consumers wrap this library:

- **Hooks** (`.claude/inspire/hooks/*.sh`) call these scripts at tool-call time
  via Claude Code's PreToolUse Bash matchers — `pre-commit.sh` on
  `git commit`, `pre-pr.sh` on `gh pr create`.
- **Skills** invoke them via the `Bash` tool inside conversational
  sessions. `/inspire_domain review` for read-only checks;
  `/inspire_domain promote` uses the write-test-revert pattern against
  `review.sh` to validate lifecycle transitions.

## Prerequisites

- `bash` (4.x+)
- `yq` (Mike Farah's Go-based version 4.x — `brew install yq`)
- `jq` (1.6+)

## Scripts

The library implements the **quality gate** (per D24 in the SDD V3 reframe addendum): the 12 rule scripts `review.sh` runs, in three severity tiers plus the style checks below them.

### Tier 1 — Mechanical blockers (always error, any lifecycle)

| Script | Checks | Notes |
|---|---|---|
| `frontmatter-mechanics.sh` | (1) `lifecycle:` present + valid enum, (2) `requires:` resolves to existing action descriptors, (3) `superseded_by:` resolves to existing object. | Three small mechanical checks grouped into one pass for efficiency. |
| `acyclic-deps.sh` | (4) action→action `requires:` graph is acyclic + no self-loops. | Uses `tsort` for cycle detection. |

### Tier 2 — Coherence blockers (error from draft+ in `04_domain`; warning in the layers that carry no lifecycle)

| Script | Checks | Notes |
|---|---|---|
| `sections-present.sh` | (5) All mandatory body sections present + non-empty (actions: Purpose / Inputs / Outputs / Entities / Behavior / Errors; entities: Purpose / Rationale / Invariants / Fields / Touched by), in the order their format spec fixes. Also checks the shape of the remaining KB layers: use-case files under `03_features/` (their sections plus the `AC-N:` id format and its within-file uniqueness), ADRs under `01_adr/` (their sections plus `### Breaking changes` under `## Consequences`), and screen files under `05_screens/` (H1, the `**Features:**` and `**Pattern:**` lines, `## Instantiation`). | Header-only sections fail. `## Touched by` is presence-only — consolidation writes it, and a zero-toucher entity legitimately has it empty. Order is checked in `04_domain` only, and ramps with the object's lifecycle. **Everything outside `04_domain` is warning-severity** and the optional screen sections (`## Module-specific deviations`, `## Current prototype`, `## Notes`) are never flagged, present or absent. |
| `no-todos.sh` | (6) No `TODO` / `FIXME` / `XXX` / `HACK` markers in body. | Per D19: files state present truth only. |
| `action-fields-in-entity.sh` | (7) Every field declared in an action's `## Entities` touch table appears in the touched entity document's `## Fields` table. | Catches drift when consolidation is skipped. |
| `entity-coherence.sh` | Field-conflict (error), field-unsourced (error), field-orphan-write (warning) across actions sharing an entity. | Distinct from #7 — these check read/write coherence *across actions*; #7 checks action ↔ entity-doc shape. |
| `stable-blockers.sh` | Every `requires:` target of a `lifecycle: stable` action is itself stable. | Action-to-action lifecycle gate. |
| `touched-entity-lifecycle.sh` | Every entity touched by a `lifecycle: stable` action is itself at `lifecycle: accepted` or higher. One-directional gate: entities promote independently. | Action ↔ entity-doc lifecycle gate. |

### Tier 3 — Lifecycle-progressive (draft → warning, accepted / stable → error, superseded → warning)

| Script | Checks | Severity model |
|---|---|---|
| `field-coverage.sh` | (8) Every field declared in an entity's `## Fields` table is touched by ≥1 action (`field-uncovered`). | Warning at draft; error at accepted and stable; warning again at superseded. |
| `rationale-wikilink.sh` | (9) Entity `## Rationale` (or action `## Purpose` ∪ `## Behavior`) contains ≥1 `[[wikilink]]`. | Warning at draft; error at accepted and stable; warning again at superseded. |
| `wikilinks-resolve.sh` | (10) Every `[[wikilink]]` in body resolves to an existing file (SDD object id or PDD/ADR basename). | Warning at draft; error at accepted and stable; warning again at superseded. |

`superseded` de-escalates rather than staying at the tier it retired from: the
object is history, kept for the pointer to what replaced it, and no longer worth
blocking a commit over (`sdd_progressive_severity` in `_lib.sh`).

### Style — the mechanical subset of the writing contract

| Script | Checks | Severity model |
|---|---|---|
| `prose-style.sh` | The greppable half of the writing contract (`.claude/skills/_references/writing-style.md`), across `04_domain`, `03_features`, `01_adr` and `05_screens`: R2 sentence cap (25 words), R4 glossary synonyms (from `00_bootstrap/glossary.md`), R5 paragraph length (6 sentences), R6 historical language (the closed token list `previously` / `used to` / `migrated from` / `~~…~~`), R1 passive voice and R3 noun clusters. Checks bind by section kind, not by file. | R1 and R3 are heuristics: **warning at every lifecycle, never ramping**. R2, R4, R5 and R6 ramp with the object's own lifecycle where one exists (`04_domain`) and are flat warnings in the three layers that carry no `lifecycle:` at all. |

**English-only in 0.7, and it says so.** When `00_bootstrap/project.md` declares
an `output_language` other than `en`, `prose-style.sh` emits one **info**-level
note — *prose-style mechanical checks are en-only in 0.7; the writing contract
still binds as authoring judgment* — and exits without checking anything. The
contract still binds everywhere; only the mechanics are `en`-shaped, because R1,
R3 and the token list are English morphology and the binding table is keyed on
English H2 names. The script's own header states what it reaches and what it does
not: table cells are never read, prose above the first H2 is never read, and the
per-field `### {field}` prose inside `## Fields` inherits its parent's tabular
kind.

### Library

| Script | Purpose | When it runs |
|---|---|---|
| `review.sh` | Composite check — orchestrates the rule scripts; aggregates findings. | `pre-commit.sh` hook on `git commit`, `pre-pr.sh` hook on `gh pr create`, the `review` skill subcommands, and the `promote` skill subcommands (write-test-revert). |
| `_lib.sh` | Shared helpers (frontmatter parsing, body-section parsing, wikilink unwrapping, severity calculation, finding emission). Sourced by other scripts. | (library — not invoked directly) |
| `trust.sh` | **A tool, not a review rule.** Artifact trust: `skill-sha` (composite hash of a deployed skill dir), `stamp` (the machine-owned `produced:` block), `endorse` (the human-owned `endorsed:` block), `report` (the trust signal). It emits no findings, is deliberately absent from `review.sh`'s `DEFAULT_RULES`, and `report` exits 0 whatever it finds — a signal, never a gate. Needs only `yq` (no `jq`), and does not source `_lib.sh`. | `stamp` / `endorse` from the owning skills; `report --summary` from the `pre-pr.sh` hook; the full `report` from `/inspire_workspace review` and the `/inspire:update` tail. |

## Output format

Findings are emitted to **stderr** as JSON lines (one finding per line):

```json
{"severity":"error","rule":"entity-coherence","target":"inspire_kb/04_domain/auth/user/auth.user.create.md","message":"..."}
```

Severity is one of `error` (blocking), `warning` (advisory) or `info` (a note
about the run itself, never about an artifact). `info` has exactly one emitter:
`prose-style.sh` announcing that a non-`en` project is out of its reach.

**Stdout** is reserved for human-readable summary output (used by skills when
they want to format findings for conversational presentation).

**Exit code:** `0` if no `error`-severity findings; `1` if any.

## Scope

The library targets action descriptors under `inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md` and the per-entity documents at `inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md` (one fewer dotted segment than the action filenames — the segment count is how discovery distinguishes them). Surface bindings (HTTP routes, CLI commands, MCP tools) live in surface-binding artifacts owned by their respective modules and are not produced by anything in this library.

`sections-present.sh` and `prose-style.sh` reach past the domain tree into `03_features/`, `01_adr/` and `05_screens/`, which makes the scope argument a contract rather than a convention.

**The scope contract.** `review.sh` forwards its single `$1` to every rule unchanged, and a rule checks exactly `$1 ∩ its own layers`. Intersection has these cases: the scope lies inside a layer (scan the scope, within that layer); the layer lies inside the scope (scan the whole layer); neither (skip that layer entirely). With no `$1` at all, every layer scans its own full root. One helper — `sdd_scope_intersect` in `_lib.sh` — answers this for every layer, including the domain finders, so no two callers can drift on what a scope means. It compares normalized paths (leading `./`, repeated `/`, trailing `/`) and falls back to a physical comparison when both sides exist, because an absolute and a relative spelling of one directory are one directory.

Two roots name those layers, and they mean different things on purpose:

- `SDD_SPEC_ROOT` (default `inspire_kb/04_domain`) — the domain tree, with exactly the meaning it has always had. Every domain rule is rooted here.
- `SDD_KB_ROOT` (default `inspire_kb`) — the KB as a whole, under which the non-domain layers sit (`$SDD_KB_ROOT/03_features`, `$SDD_KB_ROOT/01_adr`, `$SDD_KB_ROOT/05_screens`).

Both consequences follow by construction rather than by special case. A scoped domain run — `sections-present.sh inspire_kb/04_domain/auth`, which is what `promote` and a module review issue — intersects none of the newer layers and therefore checks exactly what it checked before they existed. And a KB-wide scope is a no-op for the domain rules, because `sdd_find_actions` and `sdd_find_entities` intersect with `SDD_SPEC_ROOT` before they look at anything. The dotted-leaf filename shape those two match on is a discriminator *within* the domain tree, never a claim about the rest of the KB: a screen at `05_screens/auth/user.profile.md` wears the same shape, and a gate that treated it as an action descriptor would block a PR over a file whose format it does not own.

**When the new layers are checked.** `pre-pr.sh` passes `inspire_kb`, so the whole KB is checked when a PR is opened. `pre-commit.sh` is untouched: the per-commit gate stays domain-scoped, and nothing in the three new layers can block a commit.

## Manual invocation

```bash
# Run the full review on the whole workspace
.inspire/bin/review.sh

# Run a single rule
.inspire/bin/entity-coherence.sh

# Scope to a single module
.inspire/bin/review.sh inspire_kb/04_domain/auth
```

Scripts read from the **current working directory** as the repo root. Run
them from the repo root (or pass an explicit scope path as `$1`).
