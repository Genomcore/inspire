---
name: inspire-emanate
description: "Unattended codification: emanate the knowledge base into production code as a goal-directed loop. `plan` answers what a scope would deliver, read-only; `run` launches the emanation process, which executes the waves hands-off — contracter, tester, implementer per unit, both overseers at every handoff, a deterministic gate, promotion into a branch — and ends in a written report, on a branch. Use to build a slice of the vault with no human turns in the middle; use /inspire-code for the attended cycle."
argument-hint: "plan|run [until <goal> [in N steps max]] [--scope PATH]... [args]"
user-invocable: true
---

# /inspire-emanate — Unattended emanation

Emanation is the **unattended** half of codification: `inspire-code` asks the
operator whenever it needs to, and this one answers every question at t=0 and
refuses rather than ask anything later. `plan` reads the vault and says what a
scope would deliver. `run` hands that scope to the **emanation process**, which
takes it from t=0 to a written report with zero human turns in between.

**This skill launches the process; it does not orchestrate anything.** The waves,
the spawns, the gate, promotion and the report are
`.inspire/bin/emanate-orchestrator.py`, whose specification is
`.inspire/bin/lib/orchestrator/README.md` — that is the file to read when a run
behaves in a way this one does not explain.

## plan — read-only

[`references/plan.md`](references/plan.md) is the whole subcommand: one
invocation of `.inspire/bin/emanate-plan.sh`, an answer per exit code, and the
six things a ready plan reports. Run it by hand before committing an afternoon —
or a cron line — to a run.

```
/inspire-emanate plan [until <goal>] [--scope PATH]... [--ceiling N] [--reemanate SEL]...

.inspire/bin/emanate-plan.sh --tests-root DIR [--scope PATH]... [--goal SEL] \
    [--ceiling N] [--reemanate SEL]...      # the one call it makes
```

## run — launch the process

```
uv run .inspire/bin/emanate-orchestrator.py run [--goal SEL] [--ceiling N] \
    [--scope PATH]... [--reemanate SEL]... [--variant WORD] [--rework N] \
    [--parallel N] [--budget-usd N]

uv run .inspire/bin/emanate-orchestrator.py resume <run-id>
```

The operator's phrasing translates to those arguments and nothing else:
`until <goal>` is `--goal SEL`, `in N steps max` is `--ceiling N`. Resolve prose
to one canonical selector before launching, and say which one it resolved to.

| argument | default | meaning |
|---|---|---|
| `--goal SEL` | none | the run's target. Named, it narrows the run to the goal's closure and makes an under-budgeted ceiling a **refusal**; unnamed, the run works the whole scope and delivers partially in graph order |
| `--ceiling N` | unset — the scope filter is the throttle | the maximum number of waves |
| `--scope PATH` | the whole knowledge base | repeatable KB path |
| `--reemanate SEL` | none | repeatable. Treat a graph selection as unrealized for this run |
| `--variant WORD` | none | appended to the goal slug, so two efforts over one selector get two goal branches |
| `--rework N` | 2 per handoff | overseer rework attempts at one handoff |
| `--parallel N` | 3 | how many of a wave's units run at once |
| `--budget-usd N` | unset | stop opening waves once the run's spend estimate passes it |

**Selector grammar**, one for `--goal` and `--reemanate`: `users.list` (one node)
· `users.*` (a glob) · `auth.user.list..` (the node and its transitive
dependents) · `auth.user..users.list` (the segment between two nodes). A selector
that selects nothing is the tool's usage error, never a guess to make here.

**Preflight.** The process checks every line of this and refuses with its own
message; checking first is how the operator hears it from a person rather than
from an exit code — and before a cron line exists rather than after:

- `uv` on PATH (the process resolves its own dependencies through it), and
  `claude` at 2.1.259 or above;
- a **clean launch checkout**, with `.inspire/worktrees/` and
  `.inspire/emanate-runs/` in `.gitignore`;
- `.inspire/emanate.json` — tests roots, source roots, the suite command
  (`lib/orchestrator/README.md` § What it reads);
- `plan`'s `preflight` block: the declared test-infrastructure components
  **brought up by the operator** (the process never starts a service), and the
  `worktree_recipe` without which every prepare improvises — plan's `PR-24`
  blocks a *schedule* even though it never blocks a run.

**Scheduling starts an invocation; it does not implement the loop.** A cron
entry, a CI trigger or a terminal left open runs the command above and nothing
more. A second run toward the same goal is a smaller graph by construction:
realization is read from the tests on the goal branch, so whatever the last run
promoted has already left the frontier. `resume` is the other re-entry — a
killed run, picked up from its own checkpoint.

## Reading what a run left

- **The report** — `.inspire/last-emanation.log`, committed on the goal branch,
  so it is read in the goal worktree (`.inspire/worktrees/emanate-<goal-slug>`)
  or in the PR, never in the launch checkout. Its shape is
  [`references/report-skeleton.md`](references/report-skeleton.md).
- **The work** — `git -C .inspire/worktrees/emanate-<goal-slug> log --oneline
  <launch-branch>..`. A green run ends on that branch: never a merge into the
  launch branch, never a deploy.
- **The run dir** — `.inspire/emanate-runs/<run-id>/`: `state.json`, the plan, the
  derived contracts, one record per spawn, and the checkpoint `resume` reads.

Exit `0` means the run ended and the report was written, whatever the outcome;
`3` means it refused at t=0 and nothing was spawned.

> **Output language.** Operator-facing lines this skill writes go in the
> project's declared `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Machine-read
> tokens (claim ids, selectors, branch names, filenames) stay verbatim.
