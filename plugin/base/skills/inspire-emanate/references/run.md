# Subcommand: run

The orchestrator doctrine. One invocation executes both loops — waves over the
frontier, and the role loop inside each unit — from t=0 to a written report, with
no human turn in between.

```
/inspire-emanate run until <goal> [in N steps max] [--scope PATH]... [args]
```

Everything this file describes happens in **this** session. The five personas and
overseers are spawned from here with a brief; the substrate tools are called from
here with arguments. **The orchestrator calls the tool; the tool never calls an
agent**, and no tool anywhere learns about waves, budgets or personas.

## t=0 — everything that can refuse, refuses here

In this order, and each step gates the next.

**1. Plan.** Run [`plan`](plan.md) exactly as that reference specifies and act on
its exit code. Any error-severity finding or refusal ends the run before a branch
exists. This is where every question dies.

A unit `derive` refused is worth naming, because it looks like a gap in the
schedule and is not: it stays a node in the graph at wave 1 with `claims: 0`, and
its `PR-01` is an error, so the run refuses. Cycles running through it surface
only once that `PR-01` is remedied — nothing proceeds meanwhile.

**2. Resolve the goal.** With `--goal`, the run executes `goal.units` in wave
order and the floor it is budgeted against is `goal.floor` — the deepest wave over
the goal's closure, which includes the screens that navigate *to* the goal.
`deliverable_waves` is what the declared ceiling actually permits. **A ceiling
below the effective floor refuses here** when a goal was named: a run that
provably cannot reach its goal never starts. Without a goal the same shortfall is
`PR-20`, a warning, and the run delivers partially in graph order and says so.

**3. Preflight the test infrastructure.** For every component `plan`'s
`preflight.components` names, execute the resolved framework profile's own
`## Test infrastructure` probe — for the shipped `nestjs` profile,
`docker compose config --services`, then a `ps` demanding **healthy**, not merely
`Up`. **Refuse the run when a declared component is not healthy**, naming the
components and the operator's own start command.

**The loop never starts a service.** That is the doctrine's rule, not a scruple:
the operator may have the component up on other ports, or pointed at a shared
instance, and a loop that started one would be racing them. And it is a refusal
rather than a warning because a connection error is **not a red test — it is a
suite that never ran**. An unattended run would read it as red, spend the unit's
whole rework budget proving nothing, and then cascade the stall. Where
`preflight.probe_profiles` is empty while components are declared (plan's
`PR-22`), say so in the report: nothing can tell a healthy component from a suite
that never ran, and the run proceeds at that risk.

**4. Baseline the suite.** Run the whole suite once on the branch the run was
launched from. **A red baseline in realized territory refuses the run**, naming
the failing files. Emanating onto a red suite makes every later verdict
unreadable: `GV-05` cannot tell a pre-existing failure from one this run caused,
and the first unit would burn its budget on somebody else's defect.

*Realized territory* is the qualifier that keeps this honest: what must be green
is the code the vault already claims — the tests under the resolved roots, on the
branch as found. A project with nothing built yet has no such tests and no red
baseline to have; an empty suite is not a failing one.

**5. Cut the turn branch** (§ The branch scheme) and start wave 1.

## The branch scheme

Flat, hyphenated, one namespace, **no nesting** — a branch `x` and a branch `x/y`
cannot coexist.

- **Turn branch** `emanate/<run-id>`, cut from the branch the run was launched
  on; `run-id` = UTC `yyyymmdd-HHMMSS` plus a short random suffix (two
  invocations in the same second — a scripted A/B pair — must not collide), plus
  `-<scope-slug>` when a scope filter is given.
- **Per-unit integration branch** `emanate/<run-id>-<unit-slug>`, cut from the
  turn branch when the unit's wave opens. Phase worktrees prepare from and
  harvest onto it; the orchestrator's verify runs on it; a gate pass **promotes**
  it — merged into the turn branch, then deleted. This is structural, not
  stylistic: two worktrees cannot check out one branch, so parallel units within
  a wave each need their own integration line.
- A stalled or gate-failed unit's branch is **left in place** and named in the
  run report, for autopsy; the next run neither reuses nor cleans it.
- Phase worktrees live under the house convention:
  `.claude/worktrees/emanate-<unit-slug>-<phase>`, discarded at harvest. v1
  documents the assumption of **one live run per checkout**.

## The wave schedule

One iteration is one wave. Take the wave's units from `waves[]` (or from
`goal.units` intersected with it), open an integration branch for each, and run
them **in parallel up to whatever the environment sustains**. Waves are strictly
sequential: a unit in wave *n* may read the results of wave *n−1* because those
are already merged into the turn branch, and may assume nothing about a sibling
in its own wave.

The iteration ends when every unit in the wave has reached a terminal state —
promoted, stalled, or blocked. Then re-open the next wave. The run ends when the
frontier empties, the ceiling is reached, or nothing is left that is not
downstream of a stall.

## One unit, eight phases

| phase | who | writes |
|---|---|---|
| prepare | the orchestrator | a phase worktree |
| persona | contracter · tester · implementer | inside its worktree only |
| overseer gate | security overseer · quality overseer | nothing |
| harvest | the orchestrator | one commit on the integration branch |
| verify | the orchestrator | nothing but the results manifest |
| gate | the orchestrator | nothing |
| drill | implementer, in a throwaway worktree | nothing that survives |
| promote | the orchestrator | one merge commit on the turn branch |

The first four repeat per persona: contracter, then tester, then implementer. The
last four run once, after the implementer's harvest.

### prepare

**Cut the phase worktree detached at the integration branch's tip.** It must not
check that branch out: two worktrees cannot check out one branch and verify needs
it. Detached also means the worktree is the only thing to discard afterwards.

Its content is then shaped to the phase, and the shape is the freeze:

- **contracter** — the full tree. It is writing the declarations everything
  downstream reads.
- **tester** — a **declaration-only** tree, emitted from the contracter's output
  with the language profile's `## Declaration-only tree` recipe: signatures, types
  and public surfaces present, every body absent. This is what makes the all-red
  invariant cheap: a test that passes in a tree with no bodies is asserting
  nothing, and the tester catches its own vacuity before an overseer has to. It is
  also why a unit whose framework profile reaches no language profile cannot run
  at all — the recipe has no home — and why `plan` refuses it as `PR-06` rather
  than guessing.
- **implementer** — the interfaces plus the **frozen test source**. Source, not a
  summary: an implementer who cannot read the failing assertion burns its budget
  guessing.

### persona — the spawn brief

Every brief is the same four things, and nothing in it is hard-coded here:

1. **the role shell** — the agent definition under `.claude/agents/`, which
   carries the identity and the permission envelope;
2. **the role doc pointer** — into
   [`inspire-code/references/roles/`](../../inspire-code/references/roles/README.md),
   the one doctrine both dispatch shapes read. This skill routes into
   `inspire-code` as a doctrine library; it never restates a role's judgment and
   never assumes where that library will live tomorrow;
3. **the unit's resolved profiles** — `units[].profiles` from the plan JSON: its
   matching framework profiles and the language profile each of them names;
4. **the project's wire conventions** — `wire_conventions.ids` **and** the
   decision rows, both from the plan JSON.

**Both 3 and 4 are read from the plan JSON, never from `stack.md`.** The tool
emits them precisely so this skill has no second reader of the bootstrap layer.

**A unit resolves a SET of framework profiles, and the applied rules are the union
of its members'.** A brief naming `nestjs` and `react` follows both — that is the
ordinary fullstack suite, it is the template's own default, and it refuses
nothing, for any unit kind. There is no count-based refusal here at any point: the
two unusable shapes (two frameworks sharing one `layer:`, or an empty matching
set) are `PR-07`, they are the tool's business, and they already refused at t=0.

**The set is symmetric; the payload is not.** Every entity exists in the backend
in full, and some also exist in the frontend as a **projection** over the fields
its declared usage names. Union means union of *applicable rules* — never the same
artifact emanated twice. And an uncited projection field has no oracle: it is
never claimed, so nothing gates on it.

**The tester's brief carries one line the doctrine cannot supply:** assert the
project's **recorded** wire convention, never invent one. An undecided policy row
means the convention's own default applies, and the brief carries that default
with the row that names it — so there is nothing to ask about mid-run, and no
test can pin a choice the project never made.

### the overseer gate

Both overseers read at every handoff, the implementer's exit included. They
receive the boundary, its diff, the worktree path, the unit's derived contract,
the suite result and the resolved profile set; they return approve or reject with
findings, to the orchestrator only. The contract, the finding shape and the
additive-only roster rule are the roles README's; what belongs here is the
routing:

- **a rejection routes like a failed test** — hand the findings back to the same
  persona for rework, inside the unit's budget. Never an interrupt, never a
  question;
- **a rejection is not the persona's to argue with.** An overseer never addresses
  a persona; this session decides what to hand back;
- **approvals are necessary, never sufficient.** No overseer can pass a unit over
  the deterministic gate below. A judgment oracle may only make the loop more
  conservative.

### harvest

```
.inspire/bin/emanate-harvest.sh <worktree> emanate/<run-id>-<unit-slug> \
    --label <phase> --discard -- <owned pathspec>...
```

The owned pathspec is the phase's, and it is the whole of the freeze: **source
minus tests** for the contracter and the implementer, and **the test paths the
framework profile's `## Test conventions` declares** for the tester — the one
boundary a pathspec can express, and the one that matters. Declarations versus
bodies is doctrine each persona doc states, not a path. A persona
that wrote outside its own paths is **silently dropped, never blocked**, and the
drop is reported — treat it as a signal about the phase, not as a failure.

Read the exit code rather than the diff: `0` is a commit, `6` is *nothing to
harvest* (a normal outcome the orchestrator branches on — from a persona phase it
is an infrastructural failure, below), `7` is a conflict on the integration
branch, and anything else stalls the unit naming the tool.

### verify

**Verify is the orchestrator's own evidence, and it is the reason a persona's
green is never trusted.** It runs on the integration branch, after the harvest.

**1. The whole suite.** Not the unit's tests — the whole suite. This is what
defends the kept dependents of a re-emanated piece: the gate stays unit-scoped by
construction, so breakage elsewhere has nowhere else to surface. Run it, then
normalize the runner's own output into the `inspire.suite-results/1` manifest:

```
.inspire/bin/emanate-results.sh --from FILE [--from FILE]... [--format jest] \
    [--root DIR]
```

`--from` repeats once per test command the resolved profile's `## Build &
verify` runs (the shipped stack runs unit and e2e separately); `--root` strips
the runner's absolute paths so the manifest's `file` field joins against
repo-relative `@claim` citations. The manifest's shape is
[`gate-verdict.md`](../../_references/gate-verdict.md) § Suite results and its
reader is `lib/gate-results.sh`. Nothing here restates that schema.

**2. Two repo-scoped rules, each scoped and attributed.** Both take a positional
scope, exactly as `pre-pr.sh` calls them:

```
.inspire/bin/criteria-have-tests.sh    <narrowest path holding this unit's feature artifacts>
.inspire/bin/declared-errors-tested.sh <narrowest path holding this unit's descriptors>
```

**Halt only on a finding whose subject is this unit.** The exit code is not the
answer — a rule exits 1 when *anything* in its scope errored, so read the findings
and attribute each one by its target path. **Severity is honored, never
rewritten**: a unit-subject error halts the unit before the gate, naming the
rule's own finding; anything else is reported and the unit continues. Attribution
is not re-grading — it is the same discipline `GV-05` applies to a red suite
elsewhere.

*The scoping is load-bearing, not tidiness.* `declared-errors-tested.sh` errors at
`accepted`, and the frontier **is** every `accepted` unit — so an unscoped call at
wave 2 reports every not-yet-emanated sibling as an error and halts the whole
wave. The loop would die on its own remaining work list. An unscoped call here is
a defect, not a stylistic choice.

**3. The escape-hatch ratchet.**

```
.inspire/bin/escape-hatch-ratchet.sh
```

Run it per unit, and **once more over the turn branch before the halt point**:
the ratchet is an aggregate, so per-unit passes do not imply a turn-branch pass,
and a run that reported success into a PR that is already blocked would be
lying. It takes no positional scope — the count is repo-wide by design, the same
call `pre-pr.sh` makes. On a breach, halt the unit and state the operator's
remedy verbatim — **raise the ceiling by hand, in review**. The loop never
raises one; a gate its subject can lower is not a gate.

**4. What verify does not run, said out loud.** `profile-gates-installed.sh` and
`adr-maturity-matches-features.sh` are **not** run: the first would fire
permanently on shipped profiles that carry prose quality gates and no `gates:`
frontmatter, and the second grades knowledge-base maturity, which the run never
writes and therefore can only fail on state the run did not cause. **Name both in
the report's pre-PR list** so the operator knows what the hook will still check.

Name one limitation there too: `criteria-have-tests.sh` takes its severity from
the feature's `**State:**` — a warning at 🟡 Planned, an error from 🔵 on — and only
the attended flow advances that ladder. Because this run never writes the
knowledge base, a feature it emanates stays 🟡, so the rule **warns** on precisely
the output whose tests are least proven while erroring on a human's mid-flight 🔵
feature. Verify therefore leans on the gate and the drill for the loop's own
output. The remedy is the operator's and already exists: advancing `State:` when
they accept the PR arms the rule correctly for every run afterwards. This is a
report line, not a gate.

**The gate composes on none of these rules.** No finding of theirs is translated
into a `GV-*` class, no `GV-*` class is added for them, and no severity of theirs
is overridden. They grade a path; the gate grades claims. Two questions, two
homes, no drift.

### gate

```
.inspire/bin/emanate-gate.sh --contract <the unit's derived contract> \
    --results <the manifest from THIS unit's verify run> \
    [--tests-root DIR]... [--previous <the prior contract>]
```

- **`--results` is the unit's own run.** That scoping is `GV-05`'s discipline: a
  `failed` entry in a file that cites nothing for this unit is *suite red
  elsewhere*, a finding about the run and not about the unit, and handing the gate
  somebody else's results would make it grade the wrong thing.
- **`--tests-root` is resolved here, from the framework profile's
  `## Test conventions`.** The gate never reads a profile and never guesses a
  test-path convention — it is always an argument. Pass the same roots `plan` was
  given, so coverage and realization read one set of files.
- **`--previous` on a rework cycle** (and on a re-emanation): the prior derived
  contract, which gives the verdict its claim-level `delta`. A `changed` claim
  that is also `covered` is reported in both places and is not a finding — the
  gate reports, this session decides.
- **`oracle: "store"` claims never fire `GV-01`.** A store claim is asserted
  against the schema the contracter emitted; requiring a citation would contradict
  the tester's own doctrine. An uncited one is counted, never a finding.

Exits `0`, `1` and `4` all produce a verdict on stdout — read it, do not infer it
from the exit code. `2`, `3`, `5` and `127` produce none and stall the unit,
naming the tool.

**That second group is a gate defect, not a unit outcome — no `GV-*` verdict
was reached, so nothing about the unit's own claims or tests was judged.** The
report's next-act line for a stall of this shape routes to `/inspire-lesson
note`, alongside the tool name the stall already carries: a bad `--contract`
path, a manifest the gate could not parse, a missing `jq` — these are facts
about the substrate an operator fixes once, and a lesson is what keeps the next
run from tripping the same tool defect rather than a per-unit finding nobody
outside this run would ever read again.

**A gate pass is what promotes.** An overseer's approval never substitutes for it,
and the verdict digest rides into the merge trailer.

### the mutation drill

**After the gate passes and before promote**, and only then — a unit that failed
its gate is never drilled, because survivors cannot change a verdict and drilling
it would only burn suite runs.

```
git worktree add --detach .claude/worktrees/emanate-<unit-slug>-drill <integration-branch-tip>
```

**Detached**, because two worktrees cannot check out one branch and verify has
that branch checked out already; detaching also leaves the worktree as the only
thing to discard, and it is discarded unconditionally. Then spawn the
**implementer** shell to run
[`inspire-code/references/tdd.md`](../../inspire-code/references/tdd.md) step 7
over the unit's own diff: the catalogue, k = 5–10, one mutation at a time, only
the tests covering the mutated file, reverted between, a timeout treated as
killed.

Four rules, each load-bearing:

- **the drill runs only on a unit that already passed**;
- **nothing it does may reach the integration branch.** The detached throwaway
  worktree is what makes a botched revert harmless — and the drill's own doctrine
  demands a clean tree and a perfect revert, so a botched one inside a harvested
  worktree would poison the branch;
- **the brief overrides step 7's own exit rule.** `tdd.md` tells its reader that a
  survivor sends them back to step 2 — writing the test — and the implementer
  shell can write. Handed the doc unqualified it will fix survivors in a worktree
  this run then discards: wasted turns and a survivor list that lies. **The brief
  says: run the catalogue and report; never act on a survivor**;
- **it is budgeted, abortable, and can never stall a run.** One agent turn
  allowance and a wall clock, **outside the rework budgets** because it is not a
  handoff. Exhausting either ends the drill, the report says *drill incomplete*,
  and the unit promotes anyway. A phase whose output is a measurement must not be
  able to fail a run. Where the profile declares no narrowed-test command, the
  drill is skipped and the report says so.

Survivors are recorded per unit as
`file:line — mutation applied → the test that was missing`. They are **never gate
input and never rework**: a mutation-killing test is green the moment it is
written, because the code is already correct, so such a test cannot satisfy the
all-red freeze. The signal goes where this loop already puts the human — the run
halts pre-PR, and the operator reads survivors before merging.

Its cost is real and is stated rather than buried: a worktree plus a dependency
bootstrap plus up to ten narrowed test runs per **promoted** unit.

The free half of the same idea is already in the doctrine, and costs nothing to
use: the quality overseer names which mutation would survive a weak assertion, as
a lens **at the tester gate** — judgment about tests at the one moment when the
tests exist and the code does not.

### promote

**Promotion is a merge, and nothing else.** Merge the unit's integration branch
into the turn branch, then delete the branch. The merge commit's trailers carry
the provenance: the run id, `template_sha`, the resolved profile hashes and the
gate-verdict digest (verdict plus counts).

**No run-mode step writes the knowledge base — `lifecycle:` included.** Not
prose, not frontmatter, not the tracker. `stable` stays the operator's spec-level
statement about a contract; what is built is recorded by a git branch and by the
tests themselves. Provenance is a measurement, never a gate, and it lives in git
history where it travels, cherry-picks at merge granularity (`-m 1`), and dies
with the code it describes.

Realization follows for free: the tests the tester wrote cite each claim with its
fingerprint, so the next invocation's `plan` sees the unit as realized and it
leaves the frontier. There is no registry to update and no stamp to write.

## Budgets

The documented defaults, overridable per invocation:

- per-handoff rework attempts = **2** (a third rejection at the same handoff
  stalls the unit);
- per-unit budget = **sum of the handoff allowances** (no separate knob in v1);
- global ceiling = **unset** by default (the scope filter is the throttle);
- halt = **pre-PR** by default (post-PR only as an explicit argument; never merge,
  never production).

## An infrastructural failure is not a rejection

A phase agent that crashes, returns nothing, exhausts its turn allowance, or
produces an **empty harvest** has not been rejected by anyone — nothing was
judged. Treating that as a rejection would spend a rework attempt on a defect the
persona never made, and three crashes would stall a unit no overseer ever
faulted.

- **One free retry, outside the rework budget**, at that handoff.
- **A second failure at the same handoff begins consuming rework attempts**, as a
  rejection would. Two failures in a row is no longer an accident, and a loop that
  retried an unproductive phase forever is the hang this design exists to avoid.
- **Two counters, reported separately.** The run report distinguishes
  *infrastructural retries* from *rework cycles* per unit. They mean opposite
  things — one is the harness, the other is the work — and one number covering
  both would make an unstable environment read as a weak persona.

## Arbitration — a red test against a wrong body

The implementer may not touch the tests, so a suite that stays red is a question
somebody has to answer, and it is answered **here**, never by the agent that lost
the argument.

**The derived contract is the referee.** Not the test, not the body:

- the test contradicts the contract → the **tester phase** is at fault. Hand the
  finding back at the tester handoff, inside its budget;
- the test agrees with the contract → the **body** is wrong. The implementer keeps
  its budget and reworks;
- neither can be squared with the contract because the **specification** is wrong
  or missing → the loop cannot fix it, because it never writes the knowledge base.
  **Stall the unit** and route the finding, in the report, to the skill that owns
  the artifact — `inspire-domain`, `inspire-screens` or `inspire-feature`. This is
  the attended flow's hand-back rule under an unattended posture: attended asks,
  unattended stalls and writes it down.

Never bend the code around a specification you believe is wrong, and never
"correct" the knowledge base to match the code.

## Stall, cascade and autopsy

**A stalled unit does not end the run.** A stall is: an exhausted rework budget at
some handoff, a verify halt attributable to this unit, a gate failure with no
budget left, or an unrecoverable tool error.

1. **Finish the wave in flight.** The units already running are unaffected by the
   stall; killing them would throw away work that is about to be provable.
2. **Mark everything downstream of the stalled unit `blocked` and skip it.** A
   dependent of something that was never built cannot be built either, and
   attempting it would spend a full budget discovering that.
3. **Keep running every unit that is not downstream**, wave by wave, until the
   frontier empties or the ceiling is hit.

The report names **delivered**, **stalled** and **blocked** separately. They are
three different facts — work that landed, work that was tried and failed, work
that was never attempted — and collapsing them would make a cascade read as a
mass failure.

**The autopsy is the branch, not the worktree.** The stalled phase's worktree is
**discarded without harvesting**; what is left to inspect is whatever earlier
phases already harvested onto the unit's integration branch, which is left in
place and named in the report. This is deliberate: the worktree path carries no run id,
so a surviving worktree would collide with the next run of the same unit — and
the next run would then be building on a tree nobody vouched for.

## The run report

**One file, one run: truncated at t=0 of an act-mode run, then appended to as
each wave closes.** `run` never holds the whole report in memory waiting for an
exit that might be hours away — every iteration's outcome lands in
`.inspire/last-emanation.log` as its wave finishes, so a run killed from
outside still leaves a readable partial account rather than nothing. What
**overwrites** is the next *invocation*: its own t=0 truncates whatever the
previous run left, the same way `/inspire:update` starts
`.inspire/last-upgrade.log` fresh on every upgrade. Within one run the file only
grows; across runs it never survives the next one's t=0. That file and git are
the only things a run writes outside a worktree, and neither is the knowledge
base.

**`plan` writes nothing, that file included** — [`plan`](plan.md) already
says so for the tool, and it holds here without exception: a `plan` invocation,
standalone or as `run`'s own t=0 step, never touches
`.inspire/last-emanation.log`. The log is `run`'s alone, and only from the
moment a turn branch exists.

By the final wave the file carries:

- **the run's identity** — the run id, the turn branch, the base branch, the
  scope, the goal and the selectors as typed;
- **the budget answer** — floor, effective floor with a goal, declared ceiling,
  waves actually executed;
- **delivered · stalled · blocked**, each unit named, with its integration branch
  where one was left in place;
- **per unit, beyond the gate verdict digest** — rework cycles and
  infrastructural retries as two numbers, the paths a harvest dropped, and
  three measurements the trust-report posture governs exactly as it governs
  `inspire-workspace`'s `## Signals`: reported every time, carrying no severity
  of their own, never a gate and never a reason to hold a piece back —
  - the drill's **survivors**, `file:line — mutation applied → the test that
    was missing` (or *no survivors*, the claim worth making, or *drill
    incomplete* / *drill skipped*, with the reason);
  - the **verify findings that did not halt** — everything
    `criteria-have-tests.sh` and `declared-errors-tested.sh` reported in this
    unit's scope and the unit ran past: its own warnings, *and* the
    error-severity findings whose subject is a sibling inside the same scoped
    path (§ verify item 2), which have no other home in this report. Each one
    attributed to its target the same way an error-severity halt already is, and
    each carrying the rule's own severity, honored and never rewritten — that a
    finding is an error is a fact about a path, not a verdict on this piece;
  - the **promote trailers' digest** — run id, `template_sha`, the resolved
    profile hashes, the gate-verdict digest — the same provenance the merge
    commit itself carries (§ promote), read back here so the operator has it
    without leaving the report;
- **the pre-PR list** — the rules verify did not run
  (`profile-gates-installed.sh`, `adr-maturity-matches-features.sh`) and
  `criteria-have-tests.sh`'s 🟡 limitation, so nothing about what the hook will
  still check is a surprise;
- **a gate-defect stall's next act is `/inspire-lesson note`** (§ gate),
  alongside every other stall's remedy;
- **the operator's next act** — the PR to open or already opened, and the
  remedies every stall named.

## The morning after, and A/B

Both are the operator's, and their recipes are `references/unattended.md`. What
belongs here is why nothing extra is needed to support them:

- **Reject everything** — delete the turn branch. The tests and the code die with
  it, the knowledge base never knew, and the report plus the log remain for the
  autopsy.
- **Keep parts** — promotion was per-piece merges in dependency order, so
  acceptance follows the graph: keep a prefix of the run, or revert the leaf
  pieces in the PR. Every kept piece keeps its tests (its realization) and its
  verdict trailer, and every discarded piece re-enters the next frontier
  automatically, because its citations no longer exist on the base branch.
- **A/B** — two invocations off the same base with the same `--reemanate` segment
  and different arguments (profiles, models, doctrine variants). The run-id scheme
  already isolates them into two turn branches; compare the PRs, merge the winner,
  whose trailers record which run produced what.
- **Harness drift is a measurement, never a trigger.** Drift between the current
  harness and a piece's promote trailers (`template_sha`, profile hashes) is
  surfaced, and the operator answers it — if at all — with a segment selection.
  Nothing re-emanates itself.
