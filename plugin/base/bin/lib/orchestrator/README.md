# The emanation process — what it does, and why

`.inspire/bin/emanate-orchestrator.py` plus this package **is** the unattended
emanation loop. No session orchestrates: a session (or a cron line, or a CI job)
starts one process, and that process runs the waves, spawns every agent, reads
every tool, promotes git-side and writes the report.

This file is the **specification of the process**: the rules a reader cannot
recover from the code by reading its names — the refusals, the envelopes, the
reasons a step is ordered where it is. The flow itself is declared once, in
`graph/graph.py`, and the modules named below are the nodes of it: `start` (t=0),
`handoff` (one unit's boundary sequence), `gate`, `git`, `report`, `runners`.
When this file and the code disagree, the code is what runs — but the
disagreement is a defect in one of them, and neither is free to drift.

The judgment the spawned agents apply is **not** here and is never restated here:
it is `.claude/skills/inspire-code/references/roles/`, one doc per role, read by
the attended `tdd` flow and by this process alike.

```
emanate-orchestrator.py run [--goal SEL] [--ceiling N] [--scope PATH]...
                            [--reemanate SEL]... [--variant WORD] [--rework N]
                            [--parallel N] [--budget-usd N] [--runner claude|fake:DIR]
emanate-orchestrator.py resume <run-id>
```

Exit `0` the run ended and the report was written, whatever the outcome · `2`
usage · `3` refused at t=0, nothing spawned · `4` internal.

## What it reads before it can run at all

- **`.inspire/emanate.json`** — schema `inspire.emanate-config/1`, the project's
  own declaration: `tests_roots` and `source_roots` (both non-empty), at least one
  `suite` command, and optionally `checks`, `frozen_paths`, `scaffold_paths` (the
  suite's own harness at the source root — `package.json`, the runner config, the
  lockfile — which the tester owns besides its tests roots, because nobody else
  writes it and a tree that starts empty has none), `declaration_only`,
  `narrowed_test`, `wall_clock`, `max_turns`. It is a **refusal** when it is
  missing or unusable, named problem by problem. The process reads no profile and
  scrapes no prose for these: a command it runs is a command the project wrote.
- **the plan JSON** — everything about the graph comes from `emanate-plan.sh`:
  waves, per-unit `profiles`, `wire_conventions`, `preflight.worktree_recipe`.
  `stack.md` is never read by this process; the tool is its one reader.
- **the agent shells** under `--agents-root` (default `.claude/agents`), read in
  the goal worktree. The three personas, the two shipped overseers and the arbiter
  are **non-removable** — a missing one refuses the run. The overseer roster is
  otherwise **additive-only**: an overseer is any `*-overseer.md`, a project adds
  its own, and every overseer and the arbiter must declare a `tools:` line naming
  no writing tool — an oracle writes nothing, and `Bash` can write.

## t = 0 — everything that can refuse, refuses here

Each step gates the next, and a refusal leaves nothing spawned.

1. **A clean launch checkout.** The whole of `git status --porcelain`, not
   modifications to tracked files alone: an uncommitted `/inspire:update` arrives
   as untracked files, and a run whose base is not the tree the operator is
   looking at reports work against a state nobody has. A detached `HEAD` refuses
   too — the launch branch is what every branch is cut from.
2. **`.gitignore` covers `.inspire/worktrees/` and `.inspire/emanate-runs/`.**
   The process never writes the launch checkout, and its own scratch is the first
   thing that would make it dirty and refuse the *next* run.
3. **The config, the `bin` root, `uv` on PATH, and the runner.** The `claude`
   runner drives Claude Code through the Claude Agent SDK — the same harness the
   CLI is, reached as a library rather than a command line, with the SDK's own
   bundled CLI — and refuses below the minimum CLI version it needs.
4. **The goal branch and its worktree** (§ The branch scheme). A conflict merging
   the launch branch into an existing goal branch refuses, naming the paths: the
   goal branch must never be behind its base, and a conflict resolution is a
   judgment nobody is present to make.
5. **The plan**, run in the goal worktree — realization is read from the tests on
   disk, so running it anywhere else measures a tree earlier runs never touched.
   Any error-severity finding, or a plan refusal, ends the run here. **This is
   where every question dies.**
6. **The ceiling against the floor.** With a named goal, a ceiling below
   `goal.floor` refuses: a run that provably cannot reach its goal never starts.
   Without a goal the same shortfall is plan's `PR-20`, a warning, and the run
   delivers partially in graph order.
7. **One derived contract per runnable unit.** Plan already ran derive over the
   whole frontier, so a non-zero exit here means the substrate changed under the
   run: a refusal, not a finding. A unit the ceiling puts out of reach is rostered
   as `blocked` and never derived — nothing would read its contract.
8. **The baseline.** A throwaway worktree at the goal branch's tip, the recipe run
   in it, then the whole suite. **A red baseline in realized territory refuses**:
   emanating onto a red suite makes every later verdict unreadable — `GV-05`
   cannot tell a pre-existing failure from one this run caused, and the first unit
   would burn its budget on somebody else's defect. *Realized territory* is the
   qualifier that keeps this honest: a project with no tests under the roots has
   no red baseline to have, and an empty suite is not a failing one. A recipe that
   does not produce a green suite refuses in the same breath — this is the one
   moment the recipe is proven, and proving it once is why the baseline is not cut
   in the goal worktree.
9. **The identity block** — the first thing the run writes, because everything
   above it can still refuse and a refusal may not empty the last run's account.

## The branch scheme

Flat, hyphenated, one namespace, **no nesting**.

- **Goal branch `emanate/<goal-slug>`**, cut from the launch branch, checked out
  in `.inspire/worktrees/emanate-<goal-slug>` and **kept for as long as the branch
  exists**. A goal outlives the run that works toward it: an effort takes several
  invocations, and each one has to build on what the last delivered. The slug is
  the canonical goal selector with every run of characters outside `a-z0-9`
  collapsed to one hyphen; with no goal it is the `--scope` path's last segments
  joined the same way, with neither it is `all`. `--variant <word>` appends
  `-<word>` and is the whole of the collision guard — two efforts over one
  selector are kept apart because the operator named them.
- **The branch is cut when it does not exist and the launch branch is merged into
  it when it does**, so it is never behind its base.
- **The launch checkout is never moved and never written** — not to cut the
  branch, not to merge into it, not once between t=0 and the report. A run that
  has vouched for nothing yet must not be standing in the operator's tree.
- **Per-unit integration branch `emanate/<goal-slug>-<unit-slug>-<run-stamp>`**,
  cut from the goal branch when the unit's wave opens. Two worktrees cannot check
  out one branch, so parallel units each need their own integration line, and the
  stamp is what keeps two runs toward one goal from naming the same branch.
- **Phase worktrees** are `…-<unit-slug>-<run-stamp>-<phase>`, `<phase>` one of
  `contracter`, `tester`, `implementer`, `verify`, `drill`, `baseline`, and every
  one of them is **detached** at a tip rather than checking a branch out. The path
  carries the run stamp, so a tree a killed run left behind never blocks the next
  run of the same unit — it is discarded and cut again rather than reused
  half-built.
- **The autopsy is the integration branch.** Whatever earlier phases harvested is
  on it, and it is left in place for a stalled or gate-failed unit, named in the
  report. Nothing a phase emitted is committed anywhere else: work no overseer
  approved and no gate judged does not enter a history the operator reads.
- **Two runs toward the *same* goal in one checkout collide** — one goal branch,
  one goal worktree, one report file — and nothing refuses it: the run stamp
  keeps their integration branches and phase worktrees apart, and nothing else.
  Two different goals in one checkout are independent by construction.
- **Rejecting one run is reverting the merges carrying its run-id trailer**;
  rejecting the effort is deleting the goal branch and removing its worktree. Both
  are the operator's, from the launch checkout, where they are already standing.

## The wave schedule

One iteration is one wave: the plan's `waves[]`, narrowed to the goal's closure
and truncated to the declared ceiling. The waves beyond the ceiling stay in the
roster as `blocked` — units this run knows about and will not reach is a roster
line, not an omission.

A wave's units run **in parallel**, `--parallel` wide. Waves are strictly
sequential: a unit in wave *n* may read the results of wave *n−1*, because those
are merged into the goal branch, and may **assume nothing about a sibling in its
own wave**. Inside a wave every unit advances on its own boundary and never on a
wave-wide checkpoint — waiting for a sibling is waiting for a result the unit is
forbidden to use.

A unit is skipped when it is already terminal, and **marked `blocked` when
anything it requires stalled or blocked** — a dependent of something that was
never built cannot be built either, and attempting it would spend a full budget
discovering that. The run ends when the waves are spent, the ceiling is reached,
or the spend ceiling is hit; `delivered`, `stalled` and `blocked` are reported
separately, because collapsing them would make a cascade read as a mass failure.

## One unit, its phases

| phase | who | writes |
|---|---|---|
| prepare | the process | a phase worktree |
| persona | contracter · tester · implementer | inside its worktree only |
| checks A · C | the process | nothing in a phase worktree — a suite's own reports land in the run dir |
| overseer gate | security overseer · quality overseer | nothing |
| harvest | the process | one commit on the integration branch |
| gate | the process | the results manifest and the verdict, under the run dir |
| drill | implementer, in a throwaway worktree | nothing that survives |
| promote | the process | one merge commit on the goal branch |

The first rows repeat per persona; the last three run once, after the
implementer's boundary clears.

**The `writes` column is normative.** Outside prepare and harvest the process
writes nothing inside a phase worktree — not a probe, not a scratch file, not a
fix. The worktree is the persona's evidence, and a boundary the overseers read
must be the persona's work or the gate is grading a mixture.

### prepare

The worktree is cut detached at the integration branch's tip, the recipe is run
in it **as written** — a step that fails is an infrastructural failure, not a
puzzle to solve — and the tester's tree additionally gets the project's
`declaration_only` recipe: signatures present, every body absent. That is what
makes the all-red invariant cheap: a test that passes in a tree with no bodies is
asserting nothing. Whatever the recipes wrote is then committed in the worktree
as `emanate: prepare <role>`, so the persona starts from a clean status and the
harvest's dropped set never carries the process's own packaging — a deleted
body and its declaration stub are prepare's doing, not the tester's.

**Nothing the loop runs shares a migration plane, and none of them is a plane the
operator keeps.** The units of a wave run in parallel against whatever the recipe
points them at, so a shared one has two personas writing one migration history. A
persona may apply its own migrations, because a plane thrown away at the end of
the phase freezes nothing the overseers have not approved. Which store provides
that isolation is the recipe's business; a store that offers none is a store this
loop cannot run a wave against, and the honest answer is to say so rather than
share one plane and hope.

### the spawn brief

Pointers and facts, and that is the whole of it: the role shell, the pointer at
its role doc, the unit's derived contract, its resolved `profiles`, the project's
`wire_conventions`, the owned pathspec, the environment step, the worktree. **A
unit-specific "what you emit" paragraph is forbidden**, however carefully
written: the role doc says what the role emits and the derived contract says what
this unit needs, so a third sentence can only agree redundantly or disagree
wrongly. A brief cannot make a role's judgment better, and it is the only thing
that can make it worse.

A **rework hand-back carries less**: the findings verbatim, nothing ranked,
nothing restated, no remedy of the process's own. A rejection is not the
persona's to argue with, which is exactly why it must reach it unedited.

Each spawn is a fresh headless session — never resumed, so a persona reworks from
the findings it was handed rather than from memory — carrying the shell's `tools:`
as its allowlist, a fixed non-interactive permission posture, a write fence (an
in-process `PreToolUse` hook that denies any write resolving outside the
worktree) and a deny list. **No spawned role can stall a run by asking a question**: none of the
shipped shells can prompt, and the process answers to nobody mid-wave.

### the boundary: A → harvest → C → the overseers

- **A, read-only, in the persona's own worktree.** The integration branch must not
  have moved (the branch is the process's to move), the worktree must not be
  empty, and a harvest dry-run must drop nothing. A persona that wrote outside its
  owned paths is handed that back as a rejection and the drop is reported. At the
  tester's boundary the `@claim` citations are read against the contract here,
  before anything is committed.
- **harvest** — `emanate-harvest.sh`, the phase's owned pathspec only: source
  minus tests for the contracter and the implementer, the declared tests roots plus
  `scaffold_paths` for the tester. Exit `6` is *nothing to harvest* — an infrastructural failure from a
  persona phase, never a rejection — `7` is a conflict onto the integration
  branch, and anything else stalls the unit naming the tool.
- **C, in the verify worktree at the new tip.** The project's declared `checks`,
  the escape-hatch ratchet, the frozen paths, and at the tester's boundary the two
  repo-scoped rules — `declared-errors-tested.sh` and `criteria-have-tests.sh`,
  **scoped to this unit's own artifacts and attributed by target**. Only a finding
  whose subject is this unit halts it; everything else is reported and the unit
  continues. Severity is honored, never rewritten. *The scoping is load-bearing*:
  `declared-errors-tested.sh` errors at `accepted`, and the frontier **is** every
  `accepted` unit, so an unscoped call at wave 2 would report every not-yet-built
  sibling as an error and kill the run on its own remaining work list. The
  ratchet's breach is handed back with the operator's remedy verbatim — **the
  ceiling is raised by hand, in review**; a gate its subject can lower is not a
  gate. The tester's boundary also runs the suite and fails a **vacuity** check: a
  test citing this unit's claims that passes in a tree with no bodies. *The tree
  is made that way here, not assumed to be*: the verify worktree carries the
  harvested integration tip, which holds whatever the contracter emitted, so the
  vacuity run applies the project's `declaration_only` recipe to it first and
  restores the tree afterwards. Without that, the check reads a tree the recipe
  never touched — the tester's own worktree is the only stripped one, and it is
  not where the verdict is taken — and a unit whose contracter emitted anything
  executable fails the check whatever the tester does.
- **the overseers**, both of them (and every one the project added), at every
  boundary including the implementer's exit. They read the boundary and answer in
  a structured shape; **a rejection routes like a failed test** — back to the same
  persona, inside the budget, never an interrupt and never a question. An overseer
  never addresses a persona. **Approvals are necessary, never sufficient**: no
  overseer can pass a unit over the gate below, and a judgment oracle may only
  make the loop more conservative.

### gate

`emanate-gate.sh`, in the unit's verify worktree, over this unit's own results
manifest — a `failed` entry in a file citing nothing for this unit is *suite red
elsewhere*, a fact about the run and not about the unit. The suite that feeds it
is the **whole** suite, not the unit's tests: the gate is unit-scoped by
construction, so breakage in a kept dependent has nowhere else to surface.

Exits `0`, `1` and `4` produce a verdict on stdout — it is read, never inferred
from the exit code. Anything else is a **gate defect, not a unit outcome**:
nothing about the unit's claims was judged, the unit stalls naming the tool, and
the next act is `/inspire-lesson note`, because a bad path or a missing `jq` is a
fact about the substrate an operator fixes once.

**A gate pass is what promotes**, and the verdict digest rides into the merge
trailer. An overseer's approval never substitutes for it.

### arbitration

The implementer may not touch the tests, so a suite that stays red is a question
somebody has to answer, and it is never answered by the agent that lost the
argument: a read-only `inspire-arbiter` reads each failing file and names the
party at fault — tester, body, or the specification itself. A verdict of
`specification` stalls the unit and routes the operator to the skill that owns
the artifact.

### the drill

**After the gate passes and before promote**, and only then: survivors cannot
change a verdict, so drilling a failed unit would only burn suite runs. Its own
throwaway detached worktree, the implementer shell running `tdd.md` step 7 over
the unit's diff, with the brief overriding step 7's own exit rule — **run the
catalogue and report; never act on a survivor**.

It is a **measurement, never a gate**: it is skipped where no narrowed-test
command is declared, an incomplete drill is reported as such and the unit
promotes anyway. A phase whose output is a measurement must not be able to fail a
run. Survivors are a test gap, not a code bug — the code already passed — and
they reach the operator in the report, before the PR merges.

### promote

A merge of the integration branch into the goal branch, in the goal worktree,
with the provenance in its trailers — run id, unit, `template_sha`, the resolved
profile hashes, the gate digest, the harness — then the branch is deleted with
plain `git branch -d`, which is the form that checks. A sibling that promoted
first onto a path this unit also wrote is not a conflict to resolve: the goal's
version is taken, the unit's own stays one commit back, and the persona that owns
those paths reworks the boundary.

**No step writes the knowledge base — `lifecycle:` included.** Not prose, not
frontmatter, not the tracker. `stable` stays the operator's spec-level statement
about a contract; what was built is recorded by a branch and by the tests
themselves. Realization follows for free: the tests cite each claim with its
fingerprint, so the next run's plan — read in this same worktree — sees the unit
as realized and it leaves the frontier. There is no registry to update, which is
what makes a second run toward one goal a smaller problem than the first.

## Budgets, and what is not one

- **Rework: `--rework`, 2 per handoff by default.** A third rejection at the same
  handoff stalls the unit. The per-unit budget is the sum of the handoff
  allowances; there is no separate knob.
- **An infrastructural failure is not a rejection.** A spawn that crashes, times
  out, exhausts its turns or harvests nothing has not been judged by anyone.
  **One free retry per handoff, outside the rework budget**; a second failure at
  the same handoff begins spending rework, because twice in a row is no longer an
  accident. The two counters are reported separately — one is the harness, the
  other is the work, and one number covering both would make an unstable
  environment read as a weak persona.
- **`--ceiling`** bounds the waves; **`--budget-usd`** stops opening waves once
  the run's own spend estimate passes it, blocking what is left.
- **The reach ceiling is hard**: a fully green run ends at the goal branch. The
  process never merges into the launch branch, never opens a PR and never deploys,
  and it **never starts a service** — the operator may have a component pointed at
  something shared, and a loop racing them is worse than a refusal.

## Stall

A stall is an exhausted rework budget, a halt attributable to this unit, a gate
failure with no budget left, or an unrecoverable tool error. **It ends that unit
and no other**: the wave in flight finishes, everything downstream is marked
`blocked` and skipped, and every unit that is not downstream keeps running.

## The report, the run dir, and resuming

`.inspire/last-emanation.log`, **in the goal worktree, committed on the goal
branch** as each block is written: the identity block at t=0, one block as each
wave closes, the closing block at the exit. It is `report-skeleton.md` filled,
never a shape of the process's own — a run that narrates instead produces a
diary: readable, even useful, and missing every line an operator opens the file
for. The next invocation's t=0 truncates it; every earlier run's account stays in
the branch's history. A slot with no answer carries the reason rather than
disappearing, and `status` is the one line rewritten in place, at the exit.

Git is therefore the only thing a run writes outside a worktree, and it is not
the knowledge base.

The **run dir** `.inspire/emanate-runs/<run-id>/` holds the raw facts and no
aggregate: `state.json` (the whole record, written atomically after every
transition), `plan.json`, the derived contracts, one `spawns/*.json` per spawn,
the per-round results and verdicts, and the graph's checkpoint. The report's
`### Spend` section is computed from those at write time and stored nowhere.
One line per ended run is appended to `.inspire/emanate-runs/ledger.jsonl`.

**`resume <run-id>`** picks a killed run up from its own checkpoint: the run
itself — locks, an open report, a runner — is rebuilt from `state.json`, the
phase that was in flight counts as an infrastructural ending because nobody
judged it, and the interrupted spans are marked rather than charged the downtime.
A run that already ended is not resumed; the answer there is a new run toward the
same goal, which is a smaller problem by construction.
