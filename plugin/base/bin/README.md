# `.inspire/bin/` — SDD Validation Library

Source of truth for what "review" means in the SDD layer. Shell scripts that
read filesystem state under `inspire_kb/04_domain/`, parse `.md` frontmatter, evaluate
rules, and emit structured findings.

Two consumers wrap this library:

- **Hooks** (`.claude/inspire/hooks/*.sh`) call these scripts at tool-call time
  via Claude Code's PreToolUse Bash matchers — `pre-commit.sh` on
  `git commit`, `pre-pr.sh` on `gh pr create`.
- **Skills** invoke them via the `Bash` tool inside conversational
  sessions. `/inspire-domain review` for read-only checks;
  `/inspire-domain promote` uses the write-test-revert pattern against
  `review.sh` to validate lifecycle transitions.

## Prerequisites

- `bash` (4.x+)
- `yq` (Mike Farah's Go-based version 4.x — `brew install yq`)
- `jq` (1.6+)

## Scripts

The library implements the **quality gate** (per D24 in the SDD V3 reframe addendum): the 16 rule scripts `review.sh` runs, in three severity tiers plus the style checks below them.

### Tier 1 — Mechanical blockers (always error, any lifecycle)

| Script | Checks | Notes |
|---|---|---|
| `frontmatter-mechanics.sh` | (1) `lifecycle:` present + valid enum, (2) `requires:` resolves to existing action descriptors, (3) `superseded_by:` resolves to existing object. | Three small mechanical checks grouped into one pass for efficiency. |
| `acyclic-deps.sh` | (4) action→action `requires:` graph is acyclic + no self-loops. | Uses `tsort` for cycle detection. |

### Tier 2 — Coherence blockers (error from draft+ in `04_domain`; warning in `03_features` and `01_adr`, which carry no lifecycle; ramping with the screen's own lifecycle in `05_screens`)

| Script | Checks | Notes |
|---|---|---|
| `sections-present.sh` | (5) All mandatory body sections present + non-empty (actions: the core six — Purpose / Inputs / Outputs / Entities / Behavior / Errors; entities: Purpose / Rationale / Invariants / Fields / Touched by), in the order their format spec fixes. Also checks the shape of the remaining KB layers: use-case files under `03_features/` (their sections plus the `AC-N:` id format and its within-file uniqueness), ADRs under `01_adr/` (their sections plus `### Breaking changes` under `## Consequences`), and screen files under `05_screens/` (H1, the `**Features:**` line, a non-empty `## Purpose`, a non-empty `## Bindings`, and the retired `## Instantiation` reported as such). | Header-only sections fail. `## Touched by` is presence-only — consolidation writes it, and a zero-toucher entity legitimately has it empty. Order is checked in `04_domain` only, and ramps with the object's lifecycle. **`03_features` and `01_adr` are warning-severity throughout**; screen findings ramp with the screen's own `lifecycle:`, and a screen carrying no frontmatter reads as draft. The optional screen parts (`**Pattern:**`, `**Components:**`, `## Module-specific deviations`, `## Current prototype`, `## Notes`) are never flagged, present or absent. Order is checked against the full canonical **eight** action sections, which include `## Preconditions` and `## Postconditions`; their *presence* is `keys-present.sh`'s, and there it is one of the five old-shape presence classes — a **warning at every lifecycle state in 0.8**, at pre-commit, pre-PR and `promote` alike, so a vault upgraded to 0.8 is not red on every descriptor it already had. What a keyed entry *says* is a different tier: error from `accepted` onward, everywhere the rule runs. `derive` refuses an old-shape descriptor regardless, and the presence classes ramp with the lifecycle in the release after 0.8. |
| `screen-coherence.sh` | Screen identity (`id` · `module` · `screen` · `lifecycle` present; enum valid; `id` shaped `{module}.{screen}` or `{surface}.{module}.{screen}`; `module:` agreeing with the path; `superseded_by` resolving), keyed bindings (closed subsection set, keys present and unique per subsection, dispatch outcomes naming a declared state/data key or a screen id, states anchored to something declared), and the join with the named layout (each required region that accepts `data` / `dispatch` / `nav` finds such a binding). | Ramps with the screen's own lifecycle. Three exceptions: `duplicate screen id`, `route collision` and `invalid screen lifecycle value` are errors at every state — none can fire on a pre-0.8 file; the authored-route reading is a heuristic and stays a flat warning; the to-extract-component gate is error at `stable` only. Reports the FORM of an outward reference, never its existence — `wikilinks-resolve.sh` owns resolution. |
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
| `wikilinks-resolve.sh` | (10) Every `[[wikilink]]` in body resolves to an existing file, across `04_domain` **and** `05_screens`. Four routes, in order: SDD object id, screen `id`, then — for a path-shaped target such as `../patterns/list` — its last segment, then a bare basename. | Warning at draft; error at accepted and stable; warning again at superseded. A screen with no frontmatter reads as draft. Screen file names stay positional, so a screen link resolves by id and never by path. |
| `keys-present.sh` | (11) Every section whose format spec declares keyed entries carries them, well-formed: entity `## Invariants` as `I{n}`; action `## Preconditions` / `## Postconditions` present, non-empty and keyed `P{n}` / `Q{n}`; `## Behavior` and use-case `## Main flow` steps keyed `B{n}`; `## Errors` codes unique. Heads are checked against their closed vocabulary. | Two tiers. What a keyed entry **says** (`OS-A2`, `OS-A5`, `OS-A6`, `OS-A8`, `OS-A9`, `OS-E5`, `OS-E6`) is lifecycle-progressive: warning at draft, error at accepted and stable, warning again at superseded. Whether the keyed shape **is there at all** (`OS-A1`, `OS-A3`, `OS-A4`, `OS-E3`) is a flat warning at every lifecycle in 0.8, so an upgraded vault is not red on every descriptor it already had; those four ramp in the release after. Use-case files carry no `lifecycle:` and so land on the warning side throughout, as every finding in that layer does. |
| `constraints-mechanics.sh` | (12) `Constraints:` lines are well-formed: the entity `id` marker is present, every token is a closed-vocabulary word at its own arity, and `nonnull` is rejected on an input line (the `Required` column owns required-ness). A line is read wherever in its H3 it sits; a line that is not the H3's first content line is reported as `OS-E8`. Also emits `W-1`. | Same two tiers. `OS-E2`, `OS-E4` and `OS-E8` are lifecycle-progressive; `OS-E1` (no `Constraints:` line on `id`) is a presence class and so a flat warning at every lifecycle in 0.8. `W-1` (a constraint still narrated in a `Notes` / `Description` cell) is a **flat warning forever**: recognising a constraint word in prose is a heuristic. |
| `head-referents.sh` | (13) Every name a head mentions exists: a written `unique` field obliges its action to declare a matching `unique(...)` error head (`id` exempt); invariant heads name real fields; `P` / `Q` heads name touched entities (`unchanged(...)` exempt, and resolved against disk instead); `returns(...)` names a real output; `references(...)` resolves. | Same ramp, on the lifecycle of the artifact the finding is reported against. |

`superseded` de-escalates rather than staying at the tier it retired from: the
object is history, kept for the pointer to what replaced it, and no longer worth
blocking a commit over (`sdd_progressive_severity` in `_lib.sh`).

### Style — the mechanical subset of the writing contract

| Script | Checks | Severity model |
|---|---|---|
| `prose-style.sh` | The greppable half of the writing contract (`.claude/skills/_references/writing-style.md`), across `04_domain`, `03_features`, `01_adr` and `05_screens`: R2 sentence cap (25 words), R4 glossary synonyms (from `00_bootstrap/glossary.md`), R5 paragraph length (6 sentences), R6 historical language (the closed token list `previously` / `used to` / `migrated from` / `~~…~~`), R1 passive voice and R3 noun clusters. Checks bind by section kind, not by file. | R1 and R3 are heuristics: **warning at every lifecycle, never ramping**. R2, R4, R5 and R6 ramp with the object's own lifecycle in `04_domain` and are flat warnings in every other layer: `03_features` and `01_adr` carry no `lifecycle:` for the columns to read, and `05_screens` carries one these checks deliberately do not read — a screen ramps on its contract, never on its prose. |

**English-only in 0.7, and it says so.** When `00_bootstrap/project.md` declares
an `output_language` other than English — `en`, `en-*`/`en_*` and `english` are
all read as English, case-insensitively — `prose-style.sh` emits one **info**-level
note — *prose-style mechanical checks are en-only in 0.7; the writing contract
still binds as authoring judgment* — and exits without checking anything. The
contract still binds everywhere; only the mechanics are `en`-shaped, because R1,
R3 and the token list are English morphology and the binding table is keyed on
English H2 names. The script's own header states what it reaches and what it does
not: table cells are never read, prose above the first H2 is never read, and the
per-field `### {field}` prose inside `## Fields` inherits its parent's tabular
kind.

### Source-code gates — the rules that do not read the KB alone

| Script | Checks | Notes |
|---|---|---|
| `escape-hatch-ratchet.sh` | The count of deliberate rule suppressions in the product code may fall, never rise. Per-pattern ceilings from `.escape-hatches.json`; `--update` can only lower them. | Reads `source/`, **not** `inspire_kb/`. Deliberately **absent from `review.sh`'s default rule list** — `/inspire-domain review` is a KB review and must not start judging product code. Invoked directly by `pre-commit.sh`, `pre-pr.sh` and `/inspire-code review`. |
| `declared-errors-tested.sh` | Every error an action declares in `## Errors` appears as a literal in a test file. | Reads both the KB and `source/`. Lifecycle-progressive: warning at `draft` (TDD writes the spec first), error at `accepted`+, skipped at `superseded`. Also absent from the default list, for the same reason. Wired into `pre-pr.sh`. |
| `criteria-have-tests.sh` | Every acceptance criterion carries a **stable id**, claimed by a test through `/** @covers {feature}/AC-{n} */` — qualified by the owning feature's filename stem; a bare `AC-{n}` never matches. | The larger half of "nothing untested" — errors are the small half. The id lives in an annotation, never in the test name, so CI output stays readable. Two findings: `carries no id` (untraceable by construction, so reported even when tests exist) and `is claimed by no test`. Severity from the feature's `**State:**`: warning at 🟡 Planned, error at 🔵 In progress and 🟢 Implemented. Wired into `pre-pr.sh`. |

Test-file discovery for both is in `_lib.sh` (`sdd_find_test_files`, `sdd_literal_in_tests`,
`sdd_covers_in_tests`, `SDD_TEST_SCOPE`, `SDD_TEST_GLOBS`) rather than duplicated per rule —
the two gates must agree on what a test file *is*, and the glob set already had one
silent-miss bug in it. Where the product code lives resolves in `_lib.sh` too:
`$SDD_SOURCE_ROOT` if set, else the `source_root:` frontmatter of
`00_bootstrap/stack.md` (a brownfield install sets `.` there), else `source/` — so a
project whose code is not at `source/` gets these gates pointed at the right tree
without any per-hook plumbing.

These three source-code gates are **tools with a verdict**, in the sense `trust.sh` below is a tool without
one: they emit findings and can block, but they sit outside `review.sh`'s default rules
because everything else here validates the knowledge base and these validate the code the
knowledge base produced. They are stack-agnostic — every pattern and every ceiling comes
from the project's config, so the runtime never hardcodes one language's suppression
syntax. Rationale and the ceiling-in-repo exception:
`.claude/skills/_references/quality-gates.md` Rule 4.

### Gates over the KB's own claims

| Script | Checks | Notes |
|---|---|---|
| `adr-maturity-matches-features.sh` | Every ADR a 🟢 Implemented feature links to is itself at `implemented`. | The decision layer was the only KB layer no rule read. One-directional, like `touched-entity-lifecycle.sh`: it walks features and never walks ADRs demanding features. Only 🟢 features are checked — at 🟡/🔵 a `design`-stage ADR is the ladder working. Findings are grouped per ADR, since the fix is a single `promote` however many features cite it. Takes the **features** root, so it is absent from `review.sh`'s default list, which passes the spec root. |
| `profile-gates-installed.sh` | Every quality gate a resolved stack profile **declares** in its `gates:` frontmatter is present in the project's config (or absent, where the profile rejects it). | The gate that guards the gates. Reads the frontmatter, never the `## Quality gates` prose: that prose deliberately names rules the stack **rejects**, so scraping it would demand what the reasoning refuses. Cannot see a rule that is present but switched `off` — stated in its header rather than implied. Wired into `pre-pr.sh`. |

### Library

| Script | Purpose | When it runs |
|---|---|---|
| `review.sh` | Composite check — orchestrates the rule scripts; aggregates findings. | `pre-commit.sh` hook on `git commit`, `pre-pr.sh` hook on `gh pr create`, the `review` skill subcommands, and the `promote` skill subcommands (write-test-revert). |
| `_lib.sh` | Shared helpers (frontmatter parsing, body-section parsing, wikilink unwrapping, severity calculation, finding emission). Sourced by other scripts. | (library — not invoked directly) |
| `_keyed-heads.sh` | Shared readers for the keyed-entry grammar the domain and feature formats use — entry parsing, the five closed vocabularies, head validation, `Constraints:` lines, comment stripping. Sourced by `keys-present.sh`, `constraints-mechanics.sh` and `head-referents.sh` so the three cannot drift on what a key or a head is. Deliberately absent from `DEFAULT_RULES`. | (library — not invoked directly) |
| `trust.sh` | **A tool, not a review rule.** Artifact trust: `skill-sha` (composite hash of a deployed skill dir), `stamp` (the machine-owned `produced:` block), `endorse` (the human-owned `endorsed:` block), `report` (the trust signal). It emits no findings, is deliberately absent from `review.sh`'s `DEFAULT_RULES`, and `report` exits 0 whatever it finds — a signal, never a gate. Needs only `yq` (no `jq`), and does not source `_lib.sh`. | `stamp` / `endorse` from the owning skills; `report --summary` from the `pre-pr.sh` hook; the full `report` from `/inspire-workspace review` and the `/inspire:update` tail. |
| `emanate-harvest.sh` | **A tool, not a review rule.** Worktree diff → integration-branch commit (the emanation loop's harvest step, D4/D8): diffs a phase worktree against an integration branch since their common cut point, accepts only the phase's owned git pathspecs into one commit, refuses on conflict or an empty owned diff, and discards the worktree on request. Pure git plumbing — the integration branch is never checked out, and `--mode plan`/`--dry-run` writes no ref, reflog entry or index. It emits no findings and is deliberately absent from `review.sh`'s `DEFAULT_RULES`. Needs `jq` (for its JSON summary) and does not source `_lib.sh`. | `/inspire-emanate run`'s harvest step, once per phase per unit. |
| `emanate-derive.sh` | **A tool, not a review rule.** One unit's KB artifacts → the **derived contract** on stdout as JSON (D5/D7/D8): `emanate-derive.sh <entity\|action\|screen\|component\|pattern> <id>` (or `--file <path>`) emits inputs with resolved semantic types, outputs, errors, `requires:` edges, invariants, bindings and every claim the unit makes as a keyed id plus a content fingerprint. The two catalog kinds derive from the design-system entry instead: a `component` yields its props table and its keyed states, a `pattern` its regions table and its geometry. **Strict**: an old shape is a derivation *error* naming the skill to touch the artifact with (exit 4, every class found, never the first) rather than a silently-empty section — and it refuses on a class whatever severity review reported it at, which is where the 0.8 grace on the presence classes is paid for. It re-implements no check: each `OS-*` class is verified by running the rule that owns it and reading its findings back. **The catalog kinds are the exception and consult no rule at all** — no review rule owns a catalog entry's shape (`screen-coherence` reaches a pattern only through an adopting screen), so a rule run over one would report a silence that reads as clean, and the `DR-C*` classes are the whole of their strictness rather than half of it. Writes nothing at all. Absent from `DEFAULT_RULES`. Shape, claim ids, fingerprint rule and the `DR-*` classes: [`derived-contract.md`](../skills/_references/derived-contract.md). | `/inspire-emanate plan`'s readiness pass, the gate's coverage pass, and the contracter agent, once per unit. |
| `emanate-plan.sh` | **A tool, not a review rule.** One scope's **emanation plan** on stdout as JSON (D5/D8/D10/D11): the frontier snapshot (every unit at `lifecycle: accepted`, **minus whatever is already realized**), its dependency waves, the floor those waves imply, and every readiness answer the orchestrator needs before the first worktree exists. **Realization is read from the tests** and never from the KB (`--tests-root DIR`, repeatable, no default): a unit whose every claim is cited with a matching fingerprint leaves the frontier and satisfies an edge the way a `stable` artifact does, and a frontier that is empty *because* of that is the success case — exit 0, `floor: 0`, `realized_all` — rather than `PR-12`'s refusal, which survives untouched for the vault where nothing is `accepted`. `--reemanate SEL` treats a graph selection as unrealized for the run and `--goal SEL` names the goal's remaining closure plus the floor to it (which is then the floor the ceiling is measured against), both over one selector grammar — an id · a glob · `X..` · `X..Y`. A `--reemanate` closure walks **ordering edges only**; a `--goal` closure also walks navigation **backwards** — inbound only, terminating at nav roots — so the screens that navigate to the goal come with it while a successor never does. It also reports two run-level facts a spawn brief has no other source for: `preflight` (the components `stack.md`'s `## Test infrastructure` declares, and which resolved framework profiles carry a `## Test infrastructure` probe recipe — `PR-22` warns when the first exists without the second, since an unattended run would otherwise read a connection error as red) and `wire_conventions` (the declared ids **and** the project's own decision rows). It **composes on derive** — one `emanate-derive.sh` run per frontier unit, read from stdout and never from stderr — so an old shape arrives as a `PR-01` finding rather than being re-detected. Ordering edges are `requires[]` minus navigation (a route reference, not a build-time dependency) — and only navigation, since ED10 made components and patterns units of their own, so a screen waits for its pattern's and its components' wave like any other edge; Kahn over the rest gives the waves. That same split sets severity: an unresolvable or not-yet-buildable target is an **error** on an ordering edge (`PR-02` · `PR-03`) and a **warning** on a navigation one, because a link out with nowhere to land is a broken affordance rather than a missing dependency — a screen may be emanated while the screen it links to is still a draft. Refuses in two tiers (`PR-10` · `PR-12` · `PR-13`, then `PR-11`) rather than plan a vault it cannot plan, and refuses **per unit** on profile resolution: `PR-06` when a framework profile the unit is built under reaches no `layer: language` profile, `PR-07` when a `layer:` the unit resolves carries two framework profiles — or none at all, which leaves the unit no architecture doctrine to emanate under. A set spanning two *different* layers is the ordinary fullstack suite and draws no finding. **Writes nothing at all** — not `.inspire/last-emanation.log` either. Absent from `DEFAULT_RULES`. Shape, exit codes, the `PR-*` catalogue and the wave algorithm: [`emanation-plan.md`](../skills/_references/emanation-plan.md). | `/inspire-emanate run`'s readiness pass at t=0, and an operator asking what a scope would deliver. |
| `emanate-gate.sh` | **A tool, not a review rule.** Claim coverage × citing tests × suite result → the **gate verdict** on stdout as JSON (D3/D4/D8): `emanate-gate.sh --contract FILE\|- --results FILE [--tests-root DIR]... [--previous FILE]` reads a derived contract's `claims[]`, greps the tests root(s) for `@claim` tokens (`tester.md`'s grammar), joins them against the orchestrator's `inspire.suite-results/1` manifest, and mints one `pass`/`fail` verdict plus the `GV-*` findings behind it. **Never runs a suite and never promotes** — the orchestrator does both; gate is the deterministic evidence an overseer's approval can never stand in for (D3). Writes nothing at all. Absent from `DEFAULT_RULES`. Shape, the suite-results schema, the exit codes and the `GV-*` classes: [`gate-verdict.md`](../skills/_references/gate-verdict.md). Needs `jq` and does not source `_lib.sh`. | `/inspire-emanate run`'s gate step, once per unit, before it **promotes git-side** — a merge carrying the verdict digest in a trailer, never a lifecycle edit (ED9). |
| `lib/` | The sourced units the `emanate-*` scripts share, deployed to `.inspire/bin/lib/`: `derive-json.sh` (spools, table and keyed-entry readers, fingerprints, the jq prelude), `derive-types.sh` (the universal semantic vocabulary as data, and resolution against the project's own types), `derive-refusals.sh` (the rule sweep, the class map, the `DR-*` ids), `derive-domain.sh`, `derive-screen.sh` and `derive-catalog.sh` (one per unit-kind family — the last carries the component and pattern contracts, their two renderers and the `DR-C*` classes); `plan-lib.sh` (scratch, spools, the lexical path normalizer, the owning-skill map), `plan-scan.sh` (scope, unit enumeration, the derive fan-out), `plan-stack.sh` (stack, surfaces, and both profile axes — the framework axis narrowed by the unit kind's `layer:`, and the per-framework language axis), `plan-waves.sh` (Kahn and the floor), `plan-realize.sh` (realization read from the citations, the `--reemanate` selector grammar and the `--goal` closure), `plan-checks.sh` (the `PR-*` catalogue) and `plan-report.sh` (the JSON and the grouped report), and `gate-contract.sh` / `gate-citations.sh` / `gate-results.sh` / `gate-verdict.sh` (gate's read of the derived contract, the `@claim` scan of the tests roots, its suite-results reader, and the jq join that renders both verdict shapes). **`gate-citations.sh` is the one unit two tools source**: plan reads the same scan for realization, so the citation grammar has one implementation and coverage and realization cannot come to disagree about what a token says. The `plan-*` units never source the `derive-*` ones: plan composes on `emanate-derive.sh`'s stdout, so derive's internals can move without moving plan. Sourceable on their own after `_lib.sh` + `_keyed-heads.sh` (the `derive-*` and `plan-*` units) or standalone (the `gate-*` units, which depend on none of `_lib.sh`, `_keyed-heads.sh` or `derive-*.sh`). | (libraries — not invoked directly) |

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

`sections-present.sh` and `prose-style.sh` reach past the domain tree into `03_features/`, `01_adr/` and `05_screens/`, and `keys-present.sh` into `03_features/`, which makes the scope argument a contract rather than a convention.

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
