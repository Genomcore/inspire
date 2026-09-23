# Emanation run state

`inspire.emanation-run-state/1` is the mutable execution companion to one
`inspire.emanation-plan/2` snapshot. The canonical shape is
[`emanation-run-state.schema.json`](../../bin/schemas/emanation-run-state.schema.json),
with TypeScript and Python renderings beside it. `emanate-plan.sh` remains
read-only and emits no status. The orchestrator owns this file.

The plan is saved byte-for-byte at the start of a run. `plan_sha256` binds the
sidecar to those exact bytes; a plan rewrite requires a fresh sidecar. `units`
has exactly one entry for every `waves[].units[].id`, including units later
delivered, stalled or blocked. That preserves the original graph while progress
changes. Units already in `plan.realized` and stable artifacts have no entry,
since neither was work in this snapshot.

| Unit status | Meaning |
|---|---|
| `pending` | Planned but not started; `attempt` is 0. |
| `running` | An attempt is active. `phase` and, where applicable, `persona` locate it. |
| `delivered` | The gate passed and the unit's merge landed on the goal branch. |
| `stalled` | This run attempted the unit but could not finish it. `reason` is required. |
| `blocked` | The unit was skipped because an ordering prerequisite stalled. `reason` is required; `blocked_by` names the prerequisite ids. |

`attempt` counts starts of a unit, including a later retry after a stall. Rework
cycles and infrastructure retries within an attempt have separate counters.
`integration_branch` and `worktree` point to retained evidence when present.
The run's own status is `planned`, `running`, `completed` or `interrupted`.
`updated_at` records the last atomic rewrite, not a heartbeat; a `running`
state after a crash must be reconciled with the actual agent and worktree before
another attempt begins.
After that inspection, `update ... --unit ID --status running --retry`
increments `attempt` for a fresh start from an interrupted `running` phase.
The status update records the decision; the orchestrator still has to launch
the work and honor its retry budget.

`python3 .inspire/bin/emanate-run-state.py init PLAN STATE` creates the pending
file without replacing an existing one. `update PLAN STATE` writes a root or
unit transition atomically, after validating every unit key and the plan digest.
For example:

```sh
python3 .inspire/bin/emanate-run-state.py update PLAN STATE \
  --run-status running --run-id RUN_ID --goal-branch emanate/GOAL
python3 .inspire/bin/emanate-run-state.py update PLAN STATE \
  --unit auth.user --status running --phase persona --persona tester
python3 .inspire/bin/emanate-run-state.py update PLAN STATE \
  --unit auth.user --status stalled --reason 'tester handoff exhausted'
```

The status file describes a run; it is not gate evidence or permission to
promote. A replan can trim delivered units from this snapshot for a same-contract
continuation, but it must recheck the current KB and claim fingerprints before
calling a unit realized. New work or changed contracts require the planner to
compute a new snapshot. The old plan and state remain available as run history.
