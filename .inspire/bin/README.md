# `.claude/bin/` — SDD Validation Library

Source of truth for what "review" means in the SDD layer. Shell scripts that
read filesystem state under `.inspire_kb/04_domain/`, parse `.md` frontmatter, evaluate
rules, and emit structured findings.

Two consumers wrap this library:

- **Hooks** (`.claude/hooks/*.sh`) call these scripts at tool-call time
  via Claude Code's PreToolUse Bash matchers — `pre-commit.sh` on
  `git commit`, `pre-pr.sh` on `gh pr create`.
- **Skills** invoke them via the `Bash` tool inside conversational
  sessions. `/inspire_object review` for read-only checks;
  `/inspire_object promote` uses the write-test-revert pattern against
  `review.sh` to validate lifecycle transitions.

## Prerequisites

- `bash` (4.x+)
- `yq` (Mike Farah's Go-based version 4.x — `brew install yq`)
- `jq` (1.6+)

## Scripts

The library implements the **quality gate** (per D24 in the SDD V3 reframe addendum), organised into three severity tiers across 9 rule families:

### Tier 1 — Mechanical blockers (always error, any lifecycle)

| Script | Checks | Notes |
|---|---|---|
| `frontmatter-mechanics.sh` | (1) `lifecycle:` present + valid enum, (2) `requires:` resolves to existing action descriptors, (3) `superseded_by:` resolves to existing object. | Three small mechanical checks grouped into one pass for efficiency. |
| `acyclic-deps.sh` | (4) action→action `requires:` graph is acyclic + no self-loops. | Uses `tsort` for cycle detection. |

### Tier 2 — Coherence blockers (always error, from draft+)

| Script | Checks | Notes |
|---|---|---|
| `sections-present.sh` | (5) All mandatory body sections present + non-empty (actions: Purpose / Inputs / Outputs / Entities / Behavior / Errors; entities: Purpose / Rationale / Invariants / Fields). | Header-only sections fail. |
| `no-todos.sh` | (6) No `TODO` / `FIXME` / `XXX` / `HACK` markers in body. | Per D19: files state present truth only. |
| `action-fields-in-entity.sh` | (7) Every field declared in an action's `## Entities` touch table appears in the touched entity document's `## Fields` table. | Catches drift when consolidation is skipped. |
| `entity-coherence.sh` | Field-conflict (error), field-unsourced (error), field-orphan-write (warning) across actions sharing an entity. | Distinct from #7 — these check read/write coherence *across actions*; #7 checks action ↔ entity-doc shape. |
| `stable-blockers.sh` | Every `requires:` target of a `lifecycle: stable` action is itself stable. | Action-to-action lifecycle gate. |
| `touched-entity-lifecycle.sh` | Every entity touched by a `lifecycle: stable` action is itself at `lifecycle: accepted` or higher. One-directional gate: entities promote independently. | Action ↔ entity-doc lifecycle gate. |

### Tier 3 — Lifecycle-progressive (warning at draft, error at accepted+)

| Script | Checks | Severity model |
|---|---|---|
| `field-coverage.sh` | (8) Every field declared in an entity's `## Fields` table is touched by ≥1 action (`field-uncovered`). | Warning if entity is draft; error if accepted+. |
| `rationale-wikilink.sh` | (9) Entity `## Rationale` (or action `## Purpose` ∪ `## Behavior`) contains ≥1 `[[wikilink]]`. | Warning if object is draft; error if accepted+. |
| `wikilinks-resolve.sh` | (10) Every `[[wikilink]]` in body resolves to an existing file (SDD object id or PDD/ADR basename). | Warning if object is draft; error if accepted+. |

### Library

| Script | Purpose | When it runs |
|---|---|---|
| `review.sh` | Composite check — orchestrates the rule scripts; aggregates findings. | `pre-commit.sh` hook on `git commit`, `pre-pr.sh` hook on `gh pr create`, the `review` skill subcommands, and the `promote` skill subcommands (write-test-revert). |
| `_lib.sh` | Shared helpers (frontmatter parsing, body-section parsing, wikilink unwrapping, severity calculation, finding emission). Sourced by other scripts. | (library — not invoked directly) |

## Output format

Findings are emitted to **stderr** as JSON lines (one finding per line):

```json
{"severity":"error","rule":"entity-coherence","target":".inspire_kb/04_domain/auth/user/auth.user.create.md","message":"..."}
```

Severity is one of `error` (blocking) or `warning` (advisory).

**Stdout** is reserved for human-readable summary output (used by skills when
they want to format findings for conversational presentation).

**Exit code:** `0` if no `error`-severity findings; `1` if any.

## Scope

The library targets action descriptors under `.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md` and the per-entity documents at `.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md` (one fewer dotted segment than the action filenames — the segment count is how discovery distinguishes them). Surface bindings (HTTP routes, CLI commands, MCP tools) live in surface-binding artifacts owned by their respective modules and are not produced by anything in this library.

## Manual invocation

```bash
# Run the full review on the whole workspace
.claude/bin/review.sh

# Run a single rule
.claude/bin/entity-coherence.sh

# Scope to a single module
.claude/bin/review.sh .inspire_kb/04_domain/auth
```

Scripts read from the **current working directory** as the repo root. Run
them from the repo root (or pass an explicit scope path as `$1`).
