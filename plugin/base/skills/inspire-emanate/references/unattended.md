# Running unattended

A **recipe**, not a wrapper script: how to start `/inspire-emanate run` with
nobody watching, and what the operator does the morning it stops. Nothing here
ships as an executable — a wrapper would couple the runtime to one harness's CLI
flags, the same direction rule that keeps the tool from calling an agent.

## The headless call

The harness's own non-interactive mode runs one slash-command invocation to
completion and exits — no wrapper needed, because the invocation *is* the
recipe:

```
claude -p "/inspire-emanate run until users.detail in 3 steps max"
```

Everything after the slash command is exactly what an attended operator would
type — [`SKILL.md`](../SKILL.md) § Invocation names every argument, `until` /
`--goal`, `--ceiling`, `--scope`, `--halt` included. Headless changes nothing
about the arguments; it only changes who presses return. `plan` takes the same
call shape and is the read-only half — see below.

## Permission posture: auto mode, and what it does not cover

**The run makes every tool call itself** — the orchestrator's own `Bash` and
`Agent` calls, and every persona's and overseer's, down to a spawned
implementer's `Edit` inside its own worktree. The harness's **auto mode** is
what carries that, and it is the whole of what INSPIRE prescribes: a
methodology template has no business deciding how permissions are configured in
an environment it cannot see.

**Auto mode is not a promise that nothing can prompt, and the recipe will not
pretend otherwise.** A call that falls outside what it covers still raises one,
and a prompt in an unattended run is indistinguishable from a hang: nobody is
there to answer it, so the run sits until something external kills it. That is
the trade, stated plainly — and it is why the two things that bound a run matter
**more** under this posture, not less:

- **the preflight** (§ Preflight) settles at t=0 what would otherwise be
  discovered mid-wave, when there is nobody to answer it;
- **the scope filter** keeps the run inside a path whose toolchain the operator
  already exercises by hand.

Neither is housekeeping. Together they are what keeps a run inside what auto
mode already covers.

**An operator may judge that their own environment justifies a different
posture.** That call is theirs, and its mechanics belong to the harness's
documentation rather than to this one — naming that the choice exists is honest,
shipping the recipe for it would be prescribing.

Two properties of the shipped roster are why the posture holds for what INSPIRE
ships, and both are worth stating:

- **No spawned role can stall a run by asking a question.** None of the five
  shipped role shells lists `AskUserQuestion` in its `tools:`, so no persona and
  no overseer can put a question in front of nobody mid-wave. Only the session
  that started the run can — the one place an operator already knows to look.
  That is the main structural reason an unattended run does not stall inside a
  wave.
- **A shell's `tools:` restricts and never escalates; its permission *mode* is a
  separate question.** The `tools:` line is the permission **envelope** every
  persona and overseer shell carries
  ([`inspire-code/references/roles/README.md`](../../inspire-code/references/roles/README.md)),
  and it can only narrow which tools a role may call. Mode is not covered by
  that: a subagent may declare its own `permissionMode:` in frontmatter, which
  the harness honors except under auto mode. **None of the five shipped shells
  declares one** — so the shipped roster runs under the session's own posture,
  and the overseers' read-only envelope holds by construction. That is a fact
  about these five files, not a law about agent definitions: the overseer roster
  is additive-only, so an operator who adds their own owns its envelope, the
  frontmatter INSPIRE checks nothing about included.

## Scheduling starts an invocation; it does not implement the loop

**Both loops are the skill's own** — the outer wave loop and every unit's inner
role loop run entirely inside one `run` invocation, from t=0 to the written
report, with zero human turns in between. The environment's only job is to
*start* that invocation: a cron entry, a CI job on a schedule or a trigger, a
terminal left open over a weekend. None of them drive convergence, hold state
between invocations, or need to know what a wave or a budget is — that is
exactly what `run` already owns, and building any of it again outside the
invocation would be the external loop this design specifically avoids.

**A re-invocation is simply a smaller problem, by construction.** Realization
is read from the tests on the base branch, never from a registry the scheduler
would have to maintain: whatever a prior run promoted has left the frontier, so
the next `run` — same command, same cron line, nothing to reconfigure — sees
only what remains, budgeted fresh. There is no run-to-run state to reconcile
and nothing to clean up between invocations beyond what `run` itself already
leaves (a stalled unit's branch, named in its own report, for autopsy).

`plan` is the cheap way to check whether scheduling another `run` is even
worth it: it is read-only, it writes nothing, and it answers `realized_all:
true` / `floor: 0` the moment there is nothing left to build. A schedule that
runs `plan` on a short interval and `run` on a longer one spends nothing on the
mornings there is nothing to do.

## Preflight — the thing to check before you schedule anything

`run`'s own t=0 sequence already probes the declared test-infrastructure
components and refuses the whole run when one is not healthy — see
[`run.md`](run.md) § t=0 — everything that can refuse, refuses here. That
refusal is the cheapest failure this system can produce, and also the most
annoying one to discover: a run cut at t=0 for a database that was never
brought up costs one probe when it happens *before* a cron line is written, and
costs an entire unattended window when it happens *after*. Before scheduling
anything — before the first cron entry, before the first CI trigger — run
`/inspire-emanate plan` once by hand and read its `preflight` block
([`plan.md`](plan.md) § Reporting a ready plan, item 4): every declared
component, and whether the resolved framework profile can even probe it.
Bring up what needs bringing up, name what `run` will refuse on, and only then
hand the invocation to the environment.

## The morning after

A finished run leaves a turn branch of per-piece merges, a report at
`.inspire/last-emanation.log`, and nothing merged anywhere — the hard ceiling
holds regardless of `--halt`. Three things an operator does with that, and none
of them needs the loop's help:

- **Discard everything.** Delete the turn branch. Its tests and code die with
  it, the knowledge base never knew any of it happened, and the report plus the
  log are what is left for the autopsy.
- **Keep a prefix.** Promotion was per-piece merges in dependency order, so
  acceptance follows the graph: accept the earlier waves and stop there,
  leaving the later ones for the PR review to drop.
- **Revert leaf pieces, keep the rest.** The other direction over the same
  graph — drop specific pieces with nothing downstream of them, and merge
  everything else. Either way, every kept piece keeps its own tests and its own
  verdict trailer, and every dropped piece re-enters the next `run`'s frontier
  automatically, because its citations no longer exist on the base branch once
  it is reverted.

**The mutation-drill survivors are the other half of this morning's work, and
they are a work list, not a verdict.** The run report names them per unit —
`file:line — mutation applied → the test that was missing` — and every one of
them is, by the drill's own doctrine, **a test gap, not a code bug**: the drill
never ran on a unit that failed its gate, so what survived did so against code
that was already correct. The answer is exactly what step 2 of TDD would have
produced had the drill run before promote instead of after: write the test
that kills the survivor, before the PR merges — or, for a survivor the operator
would rather have the loop retest properly, select that piece with
`--reemanate` on the next `run` rather than hand-patching it outside the loop.
A report with no survivors is a claim worth making, not silence — the report
says so plainly for that reason.

## A/B

Two invocations off the same base, the same `--reemanate` segment, and
different arguments — a profile, a model, a doctrine variant:

```
claude -p "/inspire-emanate run --reemanate auth.user.. --halt post-PR [args-A]"
claude -p "/inspire-emanate run --reemanate auth.user.. --halt post-PR [args-B]"
```

The run-id scheme already isolates the two into two turn branches — nothing
else is needed to keep them from colliding, on disk or in the report. Compare
the two PRs on their own terms and merge the winner; its merge trailers already
record which run produced what, so the losing branch is discarded exactly like
any other rejected run.
