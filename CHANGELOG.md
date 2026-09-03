# Changelog

What each INSPIRE release changed. **The convention starts at 0.9.0** — releases
0.1.0 through 0.8.0 are not back-filled, and their record is the commit history.

Each section leads with what an existing project must do, then what the release
ships: **Breaking for existing vaults**, **Added**, **Changed**, **Fixed**, in
that order, and a release omits any heading it has nothing under. Versions are
the runtime identity in `plugin/.claude-plugin/plugin.json`, which
`/inspire:init` freezes into a project's `.inspire.lock`.

## 0.9.0 — 2026-09-03

Upgrade with `/inspire:update` from any released version. Nothing moves on disk:
0.9.0 keeps the 0.3 layout and adds one payload class, `.claude/agents/`, which
arrives as a plain creation.

### Breaking for existing vaults

**Pattern and component catalog entries must declare a `**State:**` line.**
`/inspire-emanate` refuses any entry that carries none, or carries a word
outside the closed pair `to-extract` | `implemented`, as `DR-C1`. There is no
grace, no default and no seeding: the line is the entry's lifecycle, and a unit
whose lifecycle nothing states is a unit no run can place. A vault written
before 0.9 carries no such line on any entry, so **first emanation refuses until
they are added**. The remedy is to add the line to every entry under
`inspire_kb/05_screens/patterns/` and `inspire_kb/05_screens/components/` —
`to-extract` if no code stands behind it yet, `implemented` if it exists in the
code. No review rule owns a catalog entry's shape, so nothing warns ahead of
the refusal.

**The pre-PR unendorsed count jumps.** Pattern and component catalog entries are
now inside artifact trust's endorsement scope; through 0.8.0 they were excluded
by construction. So `trust.sh report --summary`, which the pre-PR hook prints,
counts every existing catalog entry as unendorsed the moment a project upgrades.
This gates nothing — the trust report carries measurements, never findings, and
is never a gate — but the number is real and it will not fall on its own.
`trust.sh endorse <file>`, run only after an explicit operator yes, is the only
thing that writes the block. A skill may recognize an endorsement moment and
propose one at a top-rung promotion, as `/inspire-domain promote` does, but
`/inspire-screens promote` — the skill that owns these entries — reaches no
such moment, so nothing will offer. Endorsement is a human act and stays one,
so a project that wants the count down endorses the entries by hand.

**The five old-shape presence classes warn everywhere in 0.9 and ramp in the
release after it.** `OS-A1`, `OS-A3`, `OS-A4`, `OS-E1` and `OS-E3` report a
domain or feature artifact written in the pre-keyed shape. In 0.9 they are flat
warnings at every lifecycle state, so an upgraded vault stays green at pre-PR
and at `promote`; in the next release they ramp with the tier-3 columns and
block at `accepted` and `stable`. **`/inspire-emanate` refuses an old-shape
artifact regardless of that grace** — the same file warns under `review` and
refuses under the loop. A touch pass through the owning skill is the migration,
and the grace is the window for it.

**Screens written before 0.9 read as `draft`.** A screen file with no
frontmatter at all — every screen any released version wrote — emits warnings
only, by design. Minting its identity block (`id` · `module` · `screen` ·
`lifecycle`) puts it on the ramp, where `## Purpose`, `## Bindings` and
screen-coherence become errors at `accepted`. Identity is write-once at every
lifecycle, `superseded` included, so mint it through `/inspire-screens update`
rather than by hand. `## Instantiation` is retired: its declarations move to
keyed `## Bindings` rows, and a screen still carrying the section is reported
on the same ramp.

### Added

- **`/inspire-emanate` — the unattended emanation loop**, the fifteenth agent
  skill and the second of the codification family. It is not an `inspire-code`
  subcommand: the session that loads it is the orchestrator. `plan` answers
  readiness read-only and refuses rather than start a run that provably cannot
  reach its goal; `run` walks each wave, spawning each of a unit's three
  personas into its own phase worktree, gating on the two overseers (which
  write nothing) and on a deterministic verdict, and promotes git-side — a
  merge carrying trailers, never a knowledge base write.
- **The `.claude/agents/` payload class**, carrying the loop's five role shells:
  `inspire-contracter`, `inspire-tester`, `inspire-implementer`,
  `inspire-security-overseer`, `inspire-quality-overseer`. A shell is an
  identity, a `tools:` permission envelope and a pointer at its doctrine. The
  overseers carry only `Read, Grep, Glob`. The overseer roster is
  additive-only: a project may add its own, and the two shipped ones cannot be
  removed.
- **The loop's mechanics in `.inspire/bin/`** — `emanate-derive.sh` (a unit's
  knowledge-base artifacts to a derived contract), `emanate-plan.sh` (frontier
  to dependency waves, with every readiness check), `emanate-gate.sh` (claims ×
  citing tests × suite result to one pass/fail verdict), `emanate-results.sh` (a
  test runner's report to the manifest the gate reads), `emanate-harvest.sh` (a
  phase worktree's owned diff to one integration commit) — plus the sourced
  units under `.inspire/bin/lib/`. These are tools, not review rules: no gate
  runs them.
- **`/inspire-screens update`** — the touch interview for an existing screen.
  The loop's refusal messages already named it; it did not exist, so a refused
  screen left the operator nowhere to go.
- **Screen substrate.** A write-once identity block, a route derived from
  `module` + `screen`, screen-owned keyed `## Bindings` (Data · Dispatches ·
  Navigation · States), a four-state lifecycle, a required `## Purpose`
  paragraph, region-shaped pattern starters, and the new rule
  `screen-coherence.sh` (identity, keyed bindings, internal references, the
  screen↔pattern-region join).
- **Keyed domain and feature shape.** Named invariants `I{n}`, keyed behavior
  steps `B{n}`, stated pre/postconditions `P{n}`/`Q{n}`, per-field
  `Constraints:` lines, and three new tier-3 rules — `keys-present.sh`,
  `constraints-mechanics.sh`, `head-referents.sh` — over one shared grammar in
  `_keyed-heads.sh`.
- **Component and pattern become emanatable unit kinds**, so a screen waits for
  its pattern's and its components' wave.
- **Readiness is read from the tests, not from the vault's word.**
  `emanate-plan`'s frontier is every `accepted` unit minus whatever the citation
  scan shows already realized, so an edge into realized work is satisfied and an
  empty frontier is a success rather than a refusal. Dependency edges are
  ordering edges only: a navigation edge warns (`PR-02` / `PR-03`) where an
  ordering one errors, because a screen may be emanated while the screen it
  links to is still a draft — a link out with nowhere to land is a broken
  affordance, not a missing dependency.
- **A language axis for stack profiles.** A framework profile names the
  `layer: language` profile it renders under; the template ships `typescript`,
  and `react`, `nestjs` and `angular` declare it. `ios` and `android`
  deliberately declare none, so the loop refuses a unit built under them
  (`PR-06`) rather than emanating it under a language it never chose.
- **Reference documents** for each new contract — `derived-contract.md`,
  `emanation-plan.md`, `gate-verdict.md`, `keyed-heads.md` — and the coding
  loop's judgment refiled **by role** under
  `inspire-code/references/roles/` (contracter · tester · implementer ·
  security overseer · quality overseer), so a rule has one home and the
  attended and unattended paths read the same doctrine.

### Changed

- **Artifact trust's endorsement scope admits pattern and component entries** —
  the change behind the count jump above. A screens `_index.md` stays outside
  it at any path: it is rebuilt nav content, so endorsing one is drift by
  construction.
- `/inspire:init` and `/inspire:update` hash in batches. Only the speed
  changes: every path materialization writes is still byte-identical to what
  the plugin ships, which is what the estate asserts. The payload itself does
  grow this release — 196 shipped paths against 0.8.0's 144 — so an upgraded
  project does gain files; the batching is not why.
- The manual documents fifteen skills, in a seven / two / six family split.
