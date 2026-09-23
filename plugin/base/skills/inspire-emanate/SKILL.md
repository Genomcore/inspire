---
name: inspire-emanate
description: Plan or run unattended emanation through the Python orchestrator and OMP Ralph loop. Use when the operator invokes /inspire-emanate.
---

# /inspire-emanate

Run the Python entry point from the repository root:

```sh
python3 orchestrator/orchestrate.py plan
python3 orchestrator/orchestrate.py run
```

`plan` prints the planner's JSON. `run` calls the same planner first, then hands
its ready JSON to the OMP Ralph loop.
When the planner refuses or reports `ready: false`, report its findings and stop.
The orchestrator owns execution and retry behavior; do not reproduce either in
this skill.
