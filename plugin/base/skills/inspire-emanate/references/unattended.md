# Running unattended

Prepare the target checkout, factory installation, model credentials and
`.inspire/emanate.json` using factory's README. Set `INSPIRE_FACTORY_ROOT` and
run INSPIRE's [readiness check](plan.md) with the actual test roots before
scheduling execution.

From the target project's root, one invocation runs to completion:

```sh
bun run "$INSPIRE_FACTORY_ROOT/orchestrator/src/orchestrate.ts" --base-branch null
```

To invoke through the skill in a headless session:

```sh
claude -p "/inspire-emanate run --base-branch null"
```

Preserve `SDD_KB_ROOT`, `SDD_SPEC_ROOT` and the configured factory location in
the launch environment. A scheduler, when requested by the operator, starts
this one command; it does not drive units, retries or merges. Configure the
host's permissions and credentials before starting unattended work.

For scoped execution, use factory's supported `--plan` export. The old
`run until ... in N steps max` flow is not an execution interface; see
[run](run.md) for the contract boundary and publication behavior.

After completion, inspect factory's `.inspire/runs/` artifacts and the release
branch. Failed runs preserve their work for recovery. Report the failed unit
and factory's error; do not force-remove worktrees, discard branches or start a
second run automatically.
