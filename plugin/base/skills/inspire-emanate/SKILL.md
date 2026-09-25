---
name: inspire-emanate
description: Plan or run unattended emanation through the INSPIRE factory's orchestrator and OMP Ralph loop. Use when the operator invokes /inspire-emanate.
---

# /inspire-emanate

The orchestrator lives in the INSPIRE factory (`Genomcore/inspire-factory`).
Run this from the repository root, with `plan` or `run` as the last word:

```sh
FACTORY="${INSPIRE_FACTORY:-$HOME/.cache/inspire-factory}"
if [ -z "$INSPIRE_FACTORY" ]; then
  [ -d "$FACTORY/.git" ] || git clone -q https://github.com/Genomcore/inspire-factory "$FACTORY"
  git -C "$FACTORY" pull -q --ff-only
fi
(cd "$FACTORY/orchestrator" && bun install --frozen-lockfile >/dev/null)
python3 "$FACTORY/orchestrator/orchestrate.py" plan
```

The first run clones the factory into `~/.cache/inspire-factory`; later runs
update it. `INSPIRE_FACTORY` points at a checkout of your own instead, which is
used as it is and never pulled.

`plan` prints the planner's JSON. `run` calls the same planner first, then hands
its ready JSON to the OMP Ralph loop.
When the planner refuses or reports `ready: false`, report its findings and stop.
The orchestrator owns execution and retry behavior; do not reproduce either in
this skill.
