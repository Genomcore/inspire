---
id: 090-emanate-runnable-worktree
title: "090 — emanate: § prepare cuts a worktree and says nothing about making it runnable"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [code, bootstrap]
status: Open
blocked_by: []
related_to: [090-emanate-wave-migrations]
---

## Description

`run.md` § prepare says to cut the phase worktree detached at the integration branch's
tip and shape its content to the phase. It says nothing about the three things that make
a fresh worktree **runnable**, and the first field run had to solve all three before its
first spawn, with fourteen minutes between invocation and the first persona:

- **Environment.** The harness safety net refuses every path whose basename is `.env`,
  read or write, so an agent can neither read the operator's `source/.env` nor place one
  in a worktree (`gs` ticket `TASK-env-blocked`). The orchestrator inferred every value
  from the committed `.env.example`, corrected the one that differed (the Postgres port),
  verified them against the live containers, and handed personas an inline export prefix
  from a file in the session scratchpad. It worked. It is also an improvisation the
  doctrine neither sanctions nor forbids, and a second run would improvise differently.
- **Dependencies.** `npm install` per worktree would cost minutes per phase. The
  orchestrator found that the monorepo's workspace links are relative, so an APFS clone
  (`cp -Rc`) of `node_modules` resolves inside the worktree in ~11 s — but **three**
  nested trees had to be cloned, not one, and `node_modules/.vite-temp` had to be removed
  or the app build failed resolving a plugin. Two gotchas, discovered by failure, recorded
  only in that run's log.
- **Generated artifacts.** The Prisma client is git-ignored and emitted to a path inside
  the API package; a worktree without it does not build.

The orchestrator then proved the worktree — build, lint, unit and e2e suites green with no
`.env` present — before spawning. That proof is the right idea and belongs in the
doctrine; the recipe belongs to the project.

## Acceptance criteria

- [ ] `run.md` § prepare states the **shape** of a runnable worktree: the environment
      comes from a project-declared, non-`.env` source read at t=0 (or exported
      variables), never from the operator's `.env`; dependencies and generated artifacts
      are provisioned by a project-declared recipe rather than a per-phase install; the
      worktree is proven runnable — the baseline suite green in it — **before** the first
      persona spawns.
- [ ] The recipe itself has a home the tool chain reads: a section of `stack.md`
      (`## Worktree recipe` or the like, seeded by `inspire-bootstrap`) or a framework
      profile section, named from `emanation-plan.md`'s run-level facts the same way
      `## Test infrastructure` is. Plan reports its absence as a warning at t=0.
- [ ] `unattended.md` § Preflight lists it: a scheduled run with no recipe is a run that
      spends its first quarter-hour improvising.
- [ ] The gs run's measured recipe (relative workspace links → clone; three nested trees;
      `.vite-temp`) is recorded as the worked example, not as the rule.

## Notes

This ticket is the operator-owned half of `TASK-env-blocked`: the harness block is not
INSPIRE's to lift, but a hands-off run has to be *designed* around it rather than
discovering it at t=0.
