---
name: inspire-emanate
description: Plan or run unattended emanation through the Python orchestrator and OMP Ralph loop. Use when the operator invokes /inspire-emanate.
---

# /inspire-emanate

Run `plan` from the project root with the installed planner, forwarding the
operator's selectors and limits unchanged:

```sh
.inspire/bin/emanate-plan.sh [--goal SEL] [--scope PATH]... [--ceiling N] [--tests-root DIR]...
```

Use `--tests-root` for every project test tree so the planner recognizes units
already realized by tests. Report its JSON and findings.

For `run`, use the installed entry point. Forward the same planner options,
including every `--tests-root`. Read the project's framework profile
`## Build & verify` commands; supply a test command that runs that suite and
produces an `inspire.suite-results/1` manifest at `--results-file` in each unit
worktree. For Jest, `.inspire/bin/emanate-results.sh` converts its JSON report.
If the project has no way to produce that manifest, refuse the run before
starting work.

```sh
python3 .inspire/bin/orchestrator/orchestrate.py run \
  --test-command JSON_ARGV --results-file .claude/worktrees/results.json \
  --tests-root tests [planner options]
```

`JSON_ARGV` is a JSON array of the project's real command and arguments. That
command must create `.claude/worktrees/results.json` and return nonzero when
the suite fails.

`plan` prints the planner's JSON. `run` calls the same planner first, then hands
its ready JSON to the OMP Ralph loop.
When the planner refuses or reports `ready: false`, report its findings and stop.
The orchestrator owns execution and retry behavior; do not reproduce either in
this skill.
