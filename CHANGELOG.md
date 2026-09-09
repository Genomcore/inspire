# Changelog

What each INSPIRE release changed. **The convention starts at 0.9.0** — releases
0.1.0 through 0.8.0 are not back-filled, and their record is the commit history.

Each section leads with what an existing project must do, then what the release
ships: **Breaking for existing vaults**, **Added**, **Changed**, **Fixed**, in
that order, and a release omits any heading it has nothing under. Versions are
the runtime identity in `plugin/.claude-plugin/plugin.json`, which
`/inspire:init` freezes into a project's `.inspire.lock`.

## 0.9.5 — 2026-09-09

Upgrade with `/inspire:update` from any released version. Nothing moves on disk,
no refusal class is added or changed, and **there is nothing to do by hand
afterwards**: 0.9.5 keeps the 0.3 layout and the 0.9.0 payload classes. Both
changes come out of the same field run 0.9.4 was written from — one fact the
emanation loop could not see, and one thing it had no home for.

### Added

**`unit.population` reaches the derived contract, so no phase reads the vault for
it.** An entity's `population: external` marker is a structural claim — no
SDD-layer action writes this entity — and until now it stopped at the knowledge
base: three rules consulted it and nothing carried it into a run. That left the
one fact telling a contracter *there is no write path to declare* and a tester
*there is none to exercise* to be inferred by personas who are forbidden to open
the vault. In the field run a contracter got it right from an invariant's prose,
and an overseer then re-derived the same fact from the entity document to rule on
the unit. `inspire.derived-contract/1` now carries it as `unit.population`, the
frontmatter value or `internal` where the field is absent, on the entity kind
alone and on the refusal object as well — a unit does not stop being externally
populated because its document is malformed. The addition is additive: a consumer
reading `.unit.kind` or `.unit.id` is untouched. `emanate-plan.sh` carries it into
`units[]` — `null` for every kind that is not an entity — and **decides nothing
with it**: no wave, no readiness class and no refusal reads the key. It is there
so which entities have no write path is legible from the plan JSON, not so a brief
can repeat it; `contracter.md` § Emission and `tester.md` § The claim list say what
it changes for each role, and `run.md` § the spawn brief now uses the marker as the
worked example of the unit-specific paragraph a brief may never write.

### Fixed

**The turn branch has a stated home, and it is not the operator's checkout.**
§ The branch scheme said where the turn branch is cut from and never where it
lives while the run does, though promote needs it checked out somewhere — a merge
commit with trailers cannot be made against a bare ref. The field run answered by
default: its reflog shows the operator's own working tree moving to the turn
branch at t=0 and still standing there a day later. Nothing was merged into it,
because that run never reached promote; the exposure is that it could have been.
A run now cuts the turn branch into a worktree of its own,
`.claude/worktrees/emanate-<run-id>`, removed at the run's end immediately before
the closing block — which is what lets that block report whether the removal
happened. **The launch checkout is never moved**, by the rule that already
detaches every phase worktree: a run that has vouched for nothing does not stand
in the operator's tree. The run report's closing block gains **where the work
is**, and `unattended.md` § The morning after now says why "delete the turn
branch" is a command the operator can actually run — nobody is standing on it.

## 0.9.4 — 2026-09-09

Upgrade with `/inspire:update` from any released version. Nothing moves on disk,
no artifact shape, rule or refusal class changes, and both findings this release
adds are **warnings**: 0.9.4 keeps the 0.3 layout and the 0.9.0 payload classes.
It is the first release written from a *field run* — one unattended
`/inspire-emanate` against a governed project — so nearly all of it is doctrine
the loop turned out not to have, rather than code.

**Two things to do in an existing project afterwards, and neither is the
upgrade's to do for you.** `00_bootstrap/stack.md` gains a `## Worktree recipe`
section, and KB seeding is additive per path — a `stack.md` already on disk is
never rewritten — so the heading has to be added by hand; the skeleton shows the
shape and `/inspire-bootstrap`'s stack interview carries the questions and a
measured example. Until it is there, `/inspire-emanate plan` warns `PR-24` on
any project that declares test-infrastructure components. Separately, `PR-25`
starts warning wherever a precondition or error states its access rule in prose
— 51 bullets across the field run's vault — which is authoring work the warning
surfaces, not a defect the upgrade introduces.

### Added

**An access rule stated in prose no longer emanates a public route in silence
(`PR-25`).** A framework profile derives a route's guard from an
`actor({role})` precondition and derives a **public** route from its absence,
and that rule is silent in both directions: a precondition that states the same
rule in prose renders no guard, derives only a test-oracle claim about its own
prose, and the suite goes green over an unguarded endpoint. Measured in the
field vault: 158 precondition bullets, none with an `actor(...)` head, 51
stating an authorization rule in prose — `workspace.user.create` would have
emanated as a public user-creation endpoint. `/inspire-emanate plan` now warns
when a headless precondition or error names an authorization concept, over the
whole frontier rather than what realization leaves, one finding per unit naming
every key. The vocabulary is `_keyed-heads.sh`'s `KH_PROSE_AUTHZ_PHRASES`,
sitting beside `W-1`'s constraint list and read by the same matcher so that one
answer to "does this prose say X" cannot become two. Both lists are heuristics,
so neither blocks anything: `ready` does not flip and the head stays the
author's to write. Plan owns the check rather than `review.sh`, because an
emanation run never invokes `review.sh` and a check the hands-off run cannot see
protects nothing.

V3 has no spelling for "any authenticated caller" and none for a membership
relationship, which is why some of those bullets are prose in the first place.
That gap is handed to `format-action.md`'s owner as a ticket rather than settled
by a warning.

**The worktree recipe: `## Worktree recipe` in `stack.md`, and `PR-24`.** A fresh
phase worktree is not a tree the suites run in, and the three things missing are
the same three in every project — environment values, dependencies, generated
artifacts. The field run improvised all three before its first spawn, for
fourteen minutes, with a person watching; unattended, that quarter-hour is
charged to the window and its conclusions are whatever the session inferred. The
recipe is now project-declared, one row per step in the order they run, read by
`plan-stack.sh` exactly as `## Test infrastructure` is and reported as
`preflight.worktree_recipe` — the one list in the plan JSON that is deliberately
**not** sorted, because the order is the recipe. It is reported and never
interpreted: which row provisions what is the project's business, and a keyed
grammar would put a schema in the knowledge base where a human writes prose.
`PR-24` warns on its absence, keyed on declared components exactly as `PR-22`
is, and `unattended.md` treats that warning as blocking a *schedule* even though
it never blocks a run.

The environment source may **not** be the operator's `.env`: an agent's harness
refuses every path whose basename is `.env`, read or write, so a recipe naming
one is a recipe no run can execute. That is verified behaviour, not a
preference.

**The run report has a shape:
`inspire-emanate/references/report-skeleton.md`.** § The run report always
specified what the log carries; it never specified a form, and the field run
produced a 299-line diary with no opening skeleton, no per-wave block and no
closing section — good content, and none of the lines an operator opens the file
for. There are now three block kinds written at three fixed moments: an identity
block at t=0, one per wave close, one at the exit. `run.md` keeps the meaning and
the skeleton keeps the form, so a line added to the list gets a slot carrying its
label and nothing more and the two files cannot drift into two answers. A slot
with no answer is filled with the reason — *drill skipped — no language profile*,
*nothing dropped* — because an absent slot reads as an oversight.

Two rules bind every slot. **The last position wins**: a conclusion the run
revises is corrected where it stands, never left beside the correction, since a
report carrying a position its author no longer holds claims something that did
not happen. **The file is tracked** — so is `.inspire/last-upgrade.log`; the
seeded `.gitignore` block names `.claude/settings.local.json` and nothing else,
so no release ever excluded either, and this states that rather than leaving it
to a default. No `/inspire:init` change: a project whose own `*.log` rule hides
the file chose that itself, and init reports what a rule shadows rather than
editing an operator's `.gitignore`.

### Changed

**A spawn brief is pointers and facts, and a unit-specific "what you emit"
paragraph is forbidden.** The field run's brief told an entity's contracter to
emit "domain type, DTOs, semantic-type validators at the owning boundary, the
Prisma model, and one migration". `contracter.md` § Emission has no such row —
an entity's fields map to the persistence model and one migration, and a DTO
renders from an **action's** inputs. The contracter obeyed the brief over its
doctrine, both overseers rejected the DTO as a mass-assignment shape, and a
rework cycle went on an instruction no persona chose. A brief cannot make a
role's judgment better, and it is the only thing that can make it worse.

A rework hand-back is a brief too, and it carries less: the overseer's findings
**verbatim**, plus any input the orchestrator corrected, and nothing else. Where
the orchestrator disagrees with an overseer it says so in the log and hands the
findings back unchanged. The eight-phase table's *writes* column is now
normative — outside prepare and harvest the orchestrator writes nothing inside a
phase worktree, and deleting a probe before harvest does not make it a
non-write, because a boundary the overseers read must be the persona's work or
the gate is grading a mixture. A claim the orchestrator wants verified goes to an
overseer or into the report as unverified. And live infrastructure is touched by
verify's declared commands and by personas in their own worktrees, by nothing
else: no ad hoc SQL, during the run or in the conversation after it.

**Nothing the loop runs shares a migration plane, and none of them is a plane the
operator keeps.** A wave's units run in parallel against whatever the recipe
points them at, so a shared store gives two personas one migration history: the
field run ended a wave with one entity's migration applied and its sibling's
pending, from two contracters that both saw the hazard and drew opposite
conclusions. Each phase worktree, and verify, now gets its own **disposable**
plane — a schema, a database, a container, whichever the recipe provides. A
store that offers no unit of isolation at all is one this loop cannot run a wave
against, and the honest answer there is to say so in the report rather than share
one plane and hope. Two consequences: a persona may apply its own migrations,
because a thrown-away plane freezes nothing the overseers have not approved; and
the loop never applies anything to a plane the operator keeps, so a run they
discard leaves their database as it found it. The migrations reach a shared plane
when the operator deploys the merged PR, in the order the files landed on the
turn branch — which is the promote order, and nothing in that chain consults a
filename's timestamp.

**An applied migration is immutable even for a comment, and verifying is not
applying.** A tool that records having run a file records a digest of it too, so
one appended line makes the file disagree with its own history. Measured on a
Prisma stack, and the shape is what matters rather than the tool: a status check
and a deploy both still reported clean while the next development-mode migrate
demanded a full schema reset — a defect that hides from the two commands anyone
would run to look for it. `contracter.md` § Persistence is append-shaped carries
it, together with what a contracter *may* do to a plane it did not create: ask
whether it is reachable and what it has run, and probe a store behaviour in a
schema it creates and drops, leaving the shared schema and the migration history
exactly as found.

**§ prepare says how a worktree becomes runnable, and the proof moved rather than
being added.** § t=0 step 4 already baselined the suite; it now does so in a
recipe-provisioned worktree, so a recipe that yields no green suite refuses the
run in the same breath as a red baseline — once, before the first spawn, rather
than per phase. It cannot be re-proven per worktree in any case: the tester's
tree has no bodies in it, so a green suite there would mean the freeze did not
happen. A recipe step that fails is an infrastructural failure, not a puzzle to
solve: an orchestrator that improvises around a broken step ships a run nobody
can reproduce.

### Fixed

**A wrapped catalog bullet no longer loses its continuation.** `derive`'s
pattern and component reader printed a `## Structure` or `## Variants` line only
when it started with a list marker, so a bullet wrapped at 80 columns reached the
derived contract as its first line only, with no refusal and no warning. In the
field run a variant arrived as *"fields bound to the study's configured value
sets,"* and lost *"each showing the code system alongside the display text"*; the
contracter, told by its doctrine that the contract is complete by construction,
froze an interface that could not express it. An item is now its marker line plus
its indented continuations, joined and normalized as one. The two exclusions are
as load-bearing as the join: a flush-left line stays **out**, because it cannot
be told from the tokens paragraph both sections sit beside, and an indented
sub-bullet opens its own item. Swallowing prose would be the same defect as
dropping it.

The domain readers need no such join and did not get one: a keyed entry's
identity is on its first line and the prose after it is diagnostic, while a
catalog bullet has no key — the prose **is** the contract. `## Notes` on a
catalog entry is ruled **not carried**, stated in `derived-contract.md` and
warned about in the pattern template, so a requirement written there is visibly a
requirement lost rather than a silent one.

**Nothing shipped links into `docs/adr/` any more.** The lessons layer README
carried a relative link that resolves to nothing in a materialized project, and
`inspire-lesson`'s `SKILL.md` and `lessons-format.md` sent an operator out of
their project by absolute URL to read the methodology's internals. All three now
state what the runtime does: nothing re-applies or archives a lesson yet, so
until that flow exists both are the operator's, and capturing still pays.

**A stamp is a column only where the entity declares the field.** `nestjs.md`'s
"Keys and stamps" read as putting `created_at` and `updated_at` on every table,
which contradicts the format it serves — stamps are declared per entity as
fields. The clause now fixes their *rendering* and never their presence, and
`contracter.md` § Emission carries the general rule: a profile's § Persistence
decides how a column is rendered, never which columns exist. An entity declaring
one stamp and not the other withheld the second.

**The canonical compile stub passes the profiles' own lint gate.** The stub rule
asked for "the smallest thing its language needs to type-check", and
`strictTypeChecked` turns `no-unused-vars` on for parameters while no framework
profile declares an `argsIgnorePattern` — so the obvious stub was a lint error,
with no escape for a class method and none the escape-hatch ratchet permits.
`typescript.md` § Compile stub now states the idiom (a throw whose message names
every parameter) and the trap. The gate is unchanged: relaxing it would weaken
`no-unused-vars` permanently for an artifact the implementer deletes.

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
