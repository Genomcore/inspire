---
name: inspire-emanate
description: Plan or run unattended emanation through the Python orchestrator and OMP Ralph loop. Use when the operator invokes /inspire-emanate.
---

# /inspire-emanate

Run the Python entry point from the repository root:

```sh
python3 orchestrator/orchestrate.py plan [--goal ID] [--scope PATH]... [--tests-root DIR]...
python3 orchestrator/orchestrate.py run  [--goal ID] [--scope PATH]... [--tests-root DIR]...
```

Forward the operator's explicit flags. `plan` prints the planner's JSON. `run`
calls the same planner first, then hands its ready JSON to the OMP Ralph loop.
When the planner refuses or reports `ready: false`, report its findings and stop.
The orchestrator owns execution and retry behavior; do not reproduce either in
this skill. For other flags, use `python3 orchestrator/orchestrate.py --help`.
