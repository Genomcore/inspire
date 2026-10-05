# Subcommand: run

Launch INSPIRE Factory once from the target project's root. Factory owns its
planner, worktrees, agents, tests, retries, merges and run storage. This session
monitors the process and reports the result; it does not reproduce those steps.

## Before launch

1. Resolve `INSPIRE_FACTORY_ROOT` and verify Bun and both factory entry points
   (`orchestrator/src/derive.ts`, `orchestrator/src/orchestrate.ts`) exist. Read
   the configured factory's README for its supported CLI and setup.
2. Run INSPIRE's [readiness plan](plan.md) from the target checkout, with the
   actual test roots. Resolve those from the project's test conventions; when
   `.inspire/emanate.json` exists, check that its `tests_roots` agree. Refuse
   execution on a readiness error, refusal or missing dependency. Report
   warnings verbatim. If everything is realized, report that and stop.
3. Preserve the requested execution scope. Factory accepts `--plan FILE` for
   `inspire.emanation-plan/3` or `inspire-factory.build-selection/1`; INSPIRE's
   `/1` readiness result is not an executable factory plan. For a selection,
   use a factory-generated export. Do not hand-convert readiness JSON.
4. Check the requested arguments against factory's CLI. Legacy `--scope`,
   `--goal`/`until`, `--ceiling`/`in N steps max`, `--reemanate`, `--rework`,
   `--variant`, `--halt`, `--profiles-root` and `--agents-root` are not factory
   execution flags. Do not ignore them or emulate them with a loop. Explain the
   unsupported request and use the factory planner to prepare a supported
   selection before any execution. `--tests-root` belongs to INSPIRE readiness;
   factory reads its own configured `tests_roots`.

## The invocation

```sh
bun run "$INSPIRE_FACTORY_ROOT/orchestrator/src/orchestrate.ts" --base-branch null
```

This is the default local run: factory creates a release branch from the current
branch, without pushing or opening a PR. Forward supported operator arguments
such as `--plan FILE`, `--concurrency N|max`, `--model PROVIDER/MODEL[:EFFORT]`
and `--keep-viewer` unchanged. Do not append a second `--base-branch` when one was
provided.

A named `--base-branch BRANCH` requests factory's publication flow: it requires
a clean checkout on that branch, `origin` and authenticated `gh`; after success
factory pushes its release branch and opens a PR against that base. Use this
mode only when the operator requested publication. Factory never merges the PR.

Keep the process running through completion and surface its output and exit
status. A failure is a result to report, not a reason for this skill to relaunch
agents or retry the command. Leave recovery to factory and the operator.

## Reporting

Read factory's run artifacts under `.inspire/runs/` and use the
[report outline](report-skeleton.md). Link to the actual run, state, branch and
PR when present. Never infer success from a partial log or maintain a parallel
`.inspire/last-emanation.log` state machine.
