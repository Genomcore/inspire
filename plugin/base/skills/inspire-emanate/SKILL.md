---
name: inspire-emanate
description: "Unattended codification through INSPIRE Factory. `plan` reads INSPIRE's readiness checks; `run` launches factory, which owns planning, agents, retries, worktrees and merges. Use /inspire-code for attended coding."
argument-hint: "plan [readiness args] | run [factory args]"
user-invocable: true
---

# /inspire-emanate — Factory launcher

INSPIRE owns specification skills and readiness checks. Factory owns contract
derivation and execution. This skill launches factory once and reports its
result; it never implements a scheduler, agent loop, retry policy or merge flow.
Factory agents load factory's own skills. INSPIRE's methodology skills and role
references remain available for attended work through `/inspire-code`.

## Configuration

Set `INSPIRE_FACTORY_ROOT` to a factory checkout containing
`orchestrator/src/derive.ts` and `orchestrator/src/orchestrate.ts`. Bun must be on
`PATH`; install factory's dependencies according to that checkout's README.
There is no default checkout location. If the setting or CLI is missing, report
that dependency and stop; do not fall back to a local derivation engine.

Run all commands from the **target project's root**, preserving `SDD_KB_ROOT`
and `SDD_SPEC_ROOT`. Never change directory into factory to execute them. Quote
the configured path and forward arguments as separate words.

## Subcommands

Read the reference for the requested subcommand before executing it.

| Subcommand | Reference |
|---|---|
| `plan [until <goal>] [--scope PATH]... [--ceiling N] [--reemanate SEL]...` | [plan](references/plan.md): INSPIRE's read-only readiness JSON, selectors, waves and `PR-*` findings |
| `run [factory args]` | [run](references/run.md): readiness first, then one factory CLI invocation |

The two planners have different contracts. INSPIRE emits
`inspire.emanation-plan/1`, including profiles, overseers, waves and readiness
checks. Factory emits `/3` with ordered units and reads its execution settings
from `.inspire/emanate.json`. **Do not pass INSPIRE's plan as factory's `--plan`,
rename its schema, or silently substitute one planner for the other.**

`until <goal>` and `in N steps max` remain shorthand for `--goal` and `--ceiling`
in **plan mode**. For execution, use factory's supported arguments or its build
planner export. Unsupported selection or budget arguments must be reported
before launch; never drop them and run the entire vault instead.

For headless operation, see [unattended](references/unattended.md). Operator-facing
prose follows the project's [output language](../_references/output-language.md)
and [writing style](../_references/writing-style.md); ids and CLI arguments stay
verbatim.
