---
name: inspire-emanate
description: Plan or run unattended emanation through the INSPIRE factory's orchestrator and OMP Ralph loop. Use when the operator invokes /inspire-emanate.
---

# /inspire-emanate

The planner and the orchestrator live in the INSPIRE factory
(`Genomcore/inspire-factory`). Run this from the repository root, ending with
the entry point for the subcommand — `src/plan.ts` for `plan`,
`src/orchestrate.ts` for `run`:

```sh
FACTORY="${INSPIRE_FACTORY:-$HOME/.cache/inspire-factory}"
if [ -z "$INSPIRE_FACTORY" ]; then
  [ -d "$FACTORY/.git" ] || git clone -q https://github.com/Genomcore/inspire-factory "$FACTORY"
  git -C "$FACTORY" pull -q --ff-only
fi
(cd "$FACTORY/orchestrator" && bun install --frozen-lockfile >/dev/null)
bun run "$FACTORY/orchestrator/src/plan.ts"
```

The first run clones the factory into `~/.cache/inspire-factory`; later runs
update it. `INSPIRE_FACTORY` points at a checkout of your own instead, which is
used as it is and never pulled.

`plan` prints the planner's `inspire.emanation-plan/3` JSON on stdout and its
grouped report on stderr; it accepts `--scope`, `--tests-root`, `--reemanate`
and `--goal`. `run` calls the same planner first, then hands its ready plan to
the orchestrator's solver. `INSPIRE_MODEL` and `INSPIRE_MAX_CONCURRENCY` in the
project's `.env` set the model and how many units run at once (default 3).
When the planner refuses or reports `ready: false`, report its findings and stop.
The orchestrator owns execution and retry behavior; do not reproduce either in
this skill.
