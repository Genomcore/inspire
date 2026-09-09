# Changelog

What each INSPIRE release changed. **The convention starts at 0.9.0** — releases
0.1.0 through 0.8.0 are not back-filled, and their record is the commit history.

Each section leads with what an existing project must do, then what the release
ships: **Breaking for existing vaults**, **Added**, **Changed**, **Fixed**, in
that order, and a release omits any heading it has nothing under. Versions are
the runtime identity in `plugin/.claude-plugin/plugin.json`, which
`/inspire:init` freezes into a project's `.inspire.lock`.

## 0.9.3 — 2026-09-09

Upgrade with `/inspire:update` from any released version. Nothing moves on disk
and nothing in a vault has to be re-authored: 0.9.3 keeps the 0.3 layout and the
0.9.0 payload classes, and no artifact shape, rule or refusal class changes. One
constraint changes **oracle**, which changes what the gate expects of an entity
unit — never what an entity document says.

### Changed

**`immutable` is a store-oracle claim, and the migration carries it.** It was a
*test*-oracle claim with nowhere to be tested: the write path a test would go
through is a repository, which the entity that declares the field never emits;
a `readonly` on a declaration is erased before the store sees an update; and the
`nestjs` profile said as much itself — *"`immutable` has no column form: it is
enforced in the repository and asserted by a test"*. Nothing enforced it. A raw
`UPDATE` changed a primary key in one statement, while the gate fired `GV-01` on
the uncited claim and stalled the unit. So the constraint takes a column form,
the way `unique` takes an index: `keyed-heads.md` § Oracles moves it to the store
row and argues it there, and the `nestjs` seed declares the form — a
`BEFORE UPDATE` trigger in the same migration that creates the column.
`contracter.md` gains the rule that a store-oracle constraint is the contracter's
alone, and refuses the emission when a profile declares no form for one rather
than emitting the field bare.

**For an entity your project already emitted, nothing retroactively grows a
trigger.** The upgrade changes what the *next* emanation emits and what the gate
expects; a table created before 0.9.3 keeps whatever it had. Re-emanating that
piece (`--reemanate`) is what produces the migration, and until then the claim is
in the same state it was in before this release — asserted by nothing.

**A rule spanning two entities is filed on the side that declares the reference.**
The same field run stalled a unit on an invariant written on the *referenced*
entity — *"every staff reference resolves to a row here"*. That entity can assert
nothing of the sort: the rows are another entity's and so is the foreign key.
Declared where it belongs, on the referring field's `references(...)`, it is a
store claim the migration already carries. `format-entity.md` § Constraints and
invariants states it, and a new *which-side* interview probe stops inviting the
wrong spelling. No rule changes: the **headed** spelling was already an error,
since every argument of a V2 head must be a field of the entity declaring it, and
the prose-only spelling is not mechanically distinguishable from legitimate prose.

**The emanation loop names what may end a turn.** `SKILL.md` promised "zero human
turns between t=0 and the report — never a waiting prompt", and no reference said
what a waiting prompt *is* in this harness: an ended turn with units short of
terminal and no agent in flight. Nothing wakes the orchestrator, so the run stops
without exiting — no report, no failure, no next wave. `run.md` § Liveness states
the rule (a turn may end in exactly two states), orders the acts that follow it —
the next spawn precedes any operator-facing text in the same turn, and the chat
gets the report once — and § The wave schedule adds the other half: a unit
advances on its own boundary, never on its wave's. `unattended.md` names the
`claude -p` turn-boundary question as **unverified** rather than guessing at it.

### Fixed

**`GV-01`'s remedy named a state the verdict schema never had.** It read *"have
the tester cite this claim, or report it as untestable"*, and no field, status or
exit represented that second branch. It now reads *"…or fix the artifact that
declares a claim no test can reach"*.

## 0.9.2 — 2026-09-08

Upgrade with `/inspire:update` from any released version. Nothing moves on disk
and nothing in a vault has to be re-authored: 0.9.2 keeps the 0.3 layout and the
0.9.0 payload classes, and no rule, refusal class or contract shape changes.

### Changed

**`/inspire:init` and `/inspire:update` do about half the process spawning they
did.** The per-file installer forked six processes for every file it wrote —
`dirname`, `mkdir -p`, `mktemp`, `cp`, `chmod`, `mv` — around 200 files per run.
The temporary file is now created by a redirect under a umask the applier pins,
so 0644 is the mode it is born with and only the two executable classes
(`bin/*.sh`, `hooks/*.sh`) still need a `chmod`; the parent directory is derived
by parameter expansion and created only when it is absent. An init drops from
~1100 spawns to ~625.

The guarantees are unchanged, and deliberately so: the write is still
temp-then-rename per file, so an interrupted run still leaves either the old
bytes or the new ones and never a half-written file; the mode still lands before
the rename; and the materialized tree is byte-for-byte and mode-for-mode
identical to what 0.9.1 produced.

**Every validator starts a little faster.** `_lib.sh` called `dirname` four
times at every source to derive the sibling KB layer roots from the spec root.
It derives the parent once, with parameter expansion, and answers exactly what
`dirname` answered — including the trailing-slash, no-slash and root cases. This
is per *invocation*, and `/inspire-emanate` spawns a validator per unit per rule,
so it compounds where it matters.

No rule, severity or refusal class changes in this release. The two runtime files
above are the only ones whose hashes moved, so an upgrade reports them as ours
and updates them; a project that had edited either is asked, as always.

## 0.9.1 — 2026-09-08

Upgrade with `/inspire:update` from any released version. Nothing moves on disk
and nothing in a vault has to be re-authored: 0.9.1 keeps the 0.3 layout and the
0.9.0 payload classes.

### Fixed

**A mutual or self foreign key no longer refuses the whole run.**
`/inspire-emanate plan` treated every `references({module}.{entity})` constraint
as an edge that orders a wave, so the two shapes present in any real data model
— a mutual pair (a case pointing at its current report while the report carries
a `nonnull` case id) and a self reference (a `supersedes_id` chain, a comment's
`parent_id`) — were cycles, and `PR-11` refused every unit in them. Nothing
warned beforehand: `acyclic-deps.sh` reads an action's frontmatter `requires:`
chain, and these edges are field constraints, so `review.sh` exits 0 on a vault
the planner then refuses.

The discriminator was already authored, and is not new vocabulary: **`nonnull`
is what makes a reference structural.** A row carrying a `nonnull` foreign key
cannot exist before its target, so the target is built first. Without `nonnull`
the reference is *deferred* — the column is populated once both sides exist —
and build order is free. Two exemptions now sit beside the navigation one, and
both **drop the ordering only**: the edge still gates readiness at error
severity, so `PR-02` and `PR-03` fire on a deferred edge exactly as before.

- **A deferred reference never orders a wave** — a `references(…)` on an entity
  **field** whose `Constraints:` line does not carry `nonnull`. An action
  **input**'s `references(…)` always orders: `nonnull` is barred from an input's
  line (`OS-A7` — the `Required` column owns required-ness), so its absence
  there says nothing.
- **A self edge never orders a wave**, unconditionally — no unit precedes
  itself, and a `nonnull` self reference is unsatisfiable as data anyway. A self
  `requires:` on an action keeps its own owner: `acyclic-deps.sh` reports it as
  a self-loop, at error severity.

**`PR-11`'s remedy names the actual lever.** The cycle arm that fires on the
wider edge set said "fix the `requires:` chain", which no field constraint has.

### Changed

**`requires[]` entries carry `ordering: bool`**, in the derived contract
(`inspire.derived-contract/1`) and in `units[].requires` of the plan
(`inspire.emanation-plan/1`). Both additions are additive — a consumer reading
`.kind` / `.id` is unaffected — and an entity reached by both a structural and a
deferred field is still **one** entry, ordering `true`.

**A `--goal` or `--reemanate` closure no longer pulls in a unit reachable only
through a deferred edge.** Closures walk ordering edges, and such a unit is not
a build-time dependency. This is the intended reading and it narrows what some
selectors match.

**A floor can shrink, never grow.** A vault whose nullable edges lengthened its
critical path gets a shorter floor, so a run that refused an under-budget
`--ceiling` may now succeed. Nothing that planned before stops planning.

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
