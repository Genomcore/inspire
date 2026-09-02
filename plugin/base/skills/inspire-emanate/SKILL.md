---
name: inspire-emanate
description: "Unattended codification: emanate the knowledge base into production code as a goal-directed loop. `plan` answers what a scope would deliver, read-only; `run` executes the waves hands-off — contracter, tester, implementer per unit, both overseers at every handoff, a deterministic gate, promotion into a branch — and ends in a written report, at most a PR. Use to build a slice of the vault with no human turns in the middle; use /inspire-code for the attended cycle."
argument-hint: "plan|run [until <goal> [in N steps max]] [--scope PATH]... [args]"
user-invocable: true
---

# /inspire-emanate — Unattended emanation

## Scope

This skill is the **orchestrator doctrine** of the emanation loop, and loading it
is what turns this session into the orchestrator. There is no sixth agent shell:
the widest permissions stay with the session the operator (or the headless
scheduler) started, and arbitration plus the report collect where the run was
kicked off.

`inspire-code` is **attended** codification; this is the **unattended** half of
the same family. The split is posture, not subject matter: every `inspire-code`
subcommand asks the operator when it needs to and never blocks, while this one
answers every question at t=0 and refuses rather than ask anything later.

**Owns:** scheduling (waves, parallelism, budgets), the phase envelope
(prepare → persona → overseer gate → harvest → verify → gate → drill →
promote), arbitration between a red test and a wrong body, and the run report.

**Does NOT own** the judgment its spawned agents apply. That is one doctrine with
two dispatch shapes, and it lives in
[`inspire-code/references/roles/`](../inspire-code/references/roles/README.md) —
the role model, the five roles, the two halves of the envelope and the overseer
contract. Read it from there; nothing here restates it, and this is the **one**
pointer at it, so a relocation of that doctrine is a one-line change in this
file.

It does not own the graph either. **The tool owns every graph mechanic** —
realization, wave layering, selector resolution, goal closure — deterministic and
golden-covered in `.inspire/bin/emanate-plan.sh`; this skill resolves the
operator's phrasing into canonical selectors, forwards arguments, and acts on
what comes back.

## The loop contract

**Both loops are this skill's own.** The operator never builds a cron, CI or
external loop to drive convergence — the environment merely *starts* an
invocation.

- **The invocation names a goal.** `run until <goal> [in N steps max]`, pursued
  hands-off to an exit condition. The goal fixes the remaining dependency closure
  and the **floor** — the minimum number of orchestrator iterations — which is
  read off the plan tool at t=0, never estimated.
- **Outer loop = orchestrator iterations.** One iteration is one wave over the
  remaining frontier, and each one advances the emanated frontier by the pieces it
  delivers.
- **Inner loops = the per-unit role loops.** Contracter → tester → implementer,
  each looping to its own exit condition: **contracter** — every contract the
  unit needs is drafted; **tester** — every claim covered by a citing test, the
  all-red invariant intact; **implementer** — the frozen suite green. The
  overseers gate between the roles, and the per-handoff budget bounds exactly
  these cycles.
- **Exits, all three of them written up:** the goal is reached · the ceiling or a
  budget is exhausted · a stall cascades. **Zero human turns between t=0 and the
  report** — never a waiting prompt, whatever happens.
- **Pieces are the reuse unit, so convergence is free.** The frontier is every
  frontier-eligible unit in scope minus the pieces whose realization is current on
  the base branch, computed from the tests themselves. A second invocation is
  simply a smaller graph with fresh budgets; re-running needs no loop design of
  its own.
- **The reach ceiling is hard.** A fully-green run ends at most in a PR — never a
  merge, never production.

## Invocation

```
/inspire-emanate plan [until <goal>] [--scope PATH]... [--ceiling N] [--reemanate SEL]...
/inspire-emanate run  [until <goal> [in N steps max]] [--scope PATH]... [args]
```

`until <goal>` and `in N steps max` are the operator's phrasing for `--goal SEL`
and `--ceiling N`; either spelling is accepted and both resolve to the same
arguments before any tool is called.

**A goal is optional and changes one thing.** Named, it narrows the run to the
goal's closure and makes an under-budgeted ceiling a **refusal**. Unnamed, the
run works the whole scope and an under-budgeted ceiling is a warning, delivering
partially in graph order.

| argument | default | meaning |
|---|---|---|
| `until <goal>` / `--goal SEL` | none | the run's target: a unit, a glob, or prose this skill resolves to a canonical dotted id. Given once |
| `in N steps max` / `--ceiling N` | **unset** — the scope filter is the throttle | the maximum number of waves this run may execute |
| `--scope PATH` | the whole knowledge base | repeatable KB path, intersected per layer through the scope contract every rule obeys |
| `--rework N` | **2** per handoff — a third rejection at the same handoff stalls the unit | overseer rework attempts at one handoff. The **per-unit budget is the sum of the handoff allowances**; there is no separate per-unit knob in v1 |
| `--halt pre-PR\|post-PR` | **pre-PR** | where a green run stops. `post-PR` opens the pull request and stops there; it is never a merge and never a deploy |
| `--reemanate SEL` | none | repeatable. Treat a graph selection as unrealized for this run; everything unselected keeps its realization |
| `--tests-root DIR` | resolved from the framework profile's `## Test conventions` | repeatable. The tree(s) `@claim` tokens are read from. Passed to both the plan tool and the gate, so realization and coverage read one set of files |
| `--profiles-root DIR` | `.claude/skills/inspire-code/profiles` | passthrough to the plan tool |
| `--agents-root DIR` | `.claude/agents` | passthrough to the plan tool |

**Selector grammar** — one grammar for `--goal` and `--reemanate`, resolved by
the tool against the frontier-eligible node set: `users.list` (one node) ·
`users.*` (a glob) · `auth.user.list..` (the node and its transitive dependents)
· `auth.user..users.list` (the segment between two nodes). Resolve the operator's
prose to one of those four before invoking anything, state which selector you
resolved it to, and let the tool answer: a selector that selects nothing is its
usage error, not a judgment call to make here.

## Subcommands

The full flow lives in a reference file. **Before executing either subcommand,
read its reference** — the table is an index, not the flow.

| Subcommand | What its reference holds |
|---|---|
| [`plan`](references/plan.md) | The read-only readiness answer: invoking `emanate-plan.sh`, acting on every exit code, reporting waves, the floor against the declared ceiling, and each `PR-*` finding with its remedy |
| [`run`](references/run.md) | The orchestrator doctrine: the t=0 preflight, the wave schedule, the eight phases of a unit, arbitration, the branch scheme, the stall cascade and the run report |

## Plan-first, and run mode never asks

**`run` executes `plan` internally before anything else and refuses the whole run
at t=0 on any readiness blocker.** Every question dies in plan mode. Nothing
downstream may ask an operator a question, offer a choice or wait — an unattended
run has nobody to answer, and a prompt is indistinguishable from a hang.

Two refusals belong to t=0 specifically:

- **the readiness refusal** — any error-severity `PR-*` finding, or a refusal
  class, and the run does not start. `references/plan.md` carries the table;
- **the goal-directed refusal** — with a named goal, a **ceiling below the floor
  to that goal refuses at t=0**. A run that provably cannot reach its goal never
  starts. The tool's own `PR-20` stays a warning, because a plain scope run with
  no named goal keeps partial-but-reported delivery in graph order; adding a goal
  is what turns the under-budget into a refusal.

Anything discovered *after* t=0 that would need an operator is a **stall**: the
unit is recorded with its findings, the run keeps going where it can, and the
answer is read from the report.

## The direction rule

**The orchestrator calls the tool; the tool never calls an agent.** Every
`.inspire/bin/emanate-*.sh` script is deterministic, writes nothing but git (and
only `harvest` does that), and spawns nothing. Every agent is spawned from here,
with a brief. Nothing in the substrate learns about waves, budgets or personas,
and nothing in this doctrine re-implements a substrate check or re-grades its
findings.

## What a run never does

- **It never writes the knowledge base** — not prose, not `lifecycle:`. Promotion
  is git-side: a unit is promoted by merging its integration branch, and the
  provenance rides in the merge commit's trailers. The KB stays the operator's
  spec-level statement, and `stable` keeps meaning what it always meant.
- **It never starts a service.** A declared test-infrastructure component that is
  not healthy refuses the run and names the operator's own start command.
- **It never raises a quality ceiling**, never rewrites a rule's severity, and
  never promotes a unit on an overseer's approval alone.
- **It never merges and never deploys**, whatever `--halt` says.

## Worked example — the canonical one

Goal: the user-detail screen. The graph, in canonical dotted ids: `users.detail`
→ `auth.user.get` → `auth.user`; `users.detail` ⇢nav⇢ `users.list`; `users.list`
→ `auth.user.list` (→ `auth.user`) + the `filtered-list` pattern → the `filter`,
`list` and `paginator` components.

- Iteration 1 — the three components + `auth.user` (4 pieces)
- Iteration 2 — `auth.user.get`, `auth.user.list`, the `filtered-list` pattern (3 pieces)
- Iteration 3 — both screens (2 pieces)

The floor is **3, not 4**. Navigation never orders a wave — list and detail
navigate to each other in every real vault, so ordering on navigation would make
this very example a cycle. A nav edge still gates readiness and still pulls the
screens that navigate *to* the goal into its closure; it skips the ordering only,
so the two screens co-emanate in the last wave. Hence
`run until the user-detail screen in 3 steps max` **succeeds** and
`in 2 steps max` **refuses at t=0**. With the `users.list` subtree already
realized by an earlier, kept run, the remaining graph is
`auth.user.get` → `users.detail`: floor 2, one piece per iteration.

The components and the pattern are units here because they are emanatable kinds,
not readiness errors on the screen that declares them: a loop that refused every
screen whose UI kit had not been hand-built first would not be hands-off at all.

## Rules

> **Output language.** Write the run report and every operator-facing line in the
> project's declared `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Machine-read
> tokens (claim ids, selectors, branch names, trailers, filenames) stay verbatim.

> **Writing contract.** The report and any prose this skill produces follow
> [`_references/writing-style.md`](../_references/writing-style.md).

> **One live run per checkout.** The branch and worktree scheme assumes it
> (`references/run.md` § The branch scheme). Two runs at once want two checkouts.
