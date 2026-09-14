---
id: 097-emanate-goal-branch
title: "097 — emanate: the run's home is a goal branch, so delivered work has a name and the next run builds on it"
created: 2026-09-10
updated: 2026-09-14
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Very High
skills: [code]
status: Open
blocked_by: []
related_to: [097-emanate-stall-discard, 090-emanate-turn-branch-home]
---

## Description

`run.md` § The branch scheme cuts a turn branch `emanate/<run-id>` from the branch the run
was launched on, checks it out in `.claude/worktrees/emanate-<run-id>`, promotes into it,
and removes the worktree immediately before the closing block. That is the 0.9.5 answer to
`090-emanate-turn-branch-home`, and the second field run (`20260910-081400-pocm`, `gs`,
2026-09-10) shows what it costs.

**The work has no legible home.** The run promoted `form` as `0b59613` on
`emanate/20260910-081400-pocm` and its report said so. The operator stands on `main`,
where `source/` is byte-identical to before the run and nothing on the branch is reachable
from a running app; finding the delivered work means reading the log for a run-id string
and cutting a worktree by hand to look at it. The name carries the run id, which says
*when* and never *what*.

**Realization does not compound across runs.** `plan` computes realization from `@claim`
citations under `--tests-root`, on disk, in the checkout it runs in
(`lib/plan-realize.sh`). The run cut from `main`; `form`'s citing tests exist only on the
turn branch. The closing block's next act says a re-run *"will have `form` realized and
outside the frontier"* and, in the same block, that the launch checkout on `main` *"is
where the next command runs from"*. Both cannot be true. The `gs` repository holds
`emanate/20260908-102102-qcpd-form` and `emanate/20260910-081400-pocm` — two independent
emanations of the same four claims — and a third run from `main` produces a third. Nothing
carries from one run to the next except the log, which the next t=0 truncates.

**Three smaller gaps land in the same place.** The gate was invoked once from the launch
checkout and returned `GV-01` on all four claims — the spec exists only on the integration
branch — and passed when re-invoked from the verify worktree; § gate names every argument
and never a working directory. The operator had run `/inspire:update` without committing,
and the orchestrator had to ask a human how to treat it before t=0 — a dead run under
`claude -p`; § Preflight does not require a clean launch checkout although every branch is
cut from it. And `.claude/worktrees/` shows as untracked in the `gs` checkout: the block
`materialize.sh` seeds into `.gitignore` names `.claude/settings.local.json` and nothing
else, and `run.md` § The run report states that as a fact.

The operator's proposal, verbatim: *carve an `emanate/<goal>` "master branch" that ends up
with all the changes that the loop harvests.*

## Acceptance criteria

- [ ] § The branch scheme replaces the per-run turn branch with a **goal branch**
      `emanate/<goal-slug>`: the canonical goal selector with dots as hyphens
      (`until workspace.login` → `emanate/workspace-login`); the scope slug the scheme
      already computes for a scope-only run; `emanate/all` for a whole-vault run; and an
      explicit `--variant` for an A/B pair (`emanate/workspace-login-a`), replacing the
      random suffix as the collision guard. The namespace stays flat and hyphenated.
- [ ] **t=0:** the goal branch is cut from the launch branch when it does not exist and
      the launch branch is merged into it when it does, so it is never behind its base; a
      merge conflict refuses at t=0; a dirty launch checkout refuses at t=0, with the
      reason in the message. `plan` runs in the goal worktree, so the realized set is what
      earlier runs toward this goal promoted.
- [ ] The goal worktree `.claude/worktrees/emanate-<goal-slug>` **persists while the
      branch exists**; a later run finds and reuses it; the closing block names the branch,
      the worktree path, the one command that shows the work
      (`git -C <worktree> log --oneline <base>..`) and the diff-stat against the base.
- [ ] Per-unit integration branches are `emanate/<goal-slug>-<unit-slug>-<run-stamp>`,
      cut from the goal branch and promoted into it with today's trailers; the run id stays
      a trailer and the log's identity. "Reject one run" is documented as reverting the
      merges carrying its trailer; "reject the effort" as deleting the branch and the
      worktree, standing on neither.
- [ ] **Every tool that reads tests names its working directory** in doctrine: `plan` in
      the goal worktree, `results` and `gate` in the unit's verify worktree. § gate and
      § verify say so.
- [ ] The run log is committed on the goal branch at each block it writes, so it travels
      with the work and the launch checkout is never written — **or** the ticket decides
      the log stays where it is and § The run report says which commit carries it.
- [ ] `materialize.sh`'s seeded `.gitignore` block adds `.claude/worktrees/`; a
      `materialize/` test asserts the line on init and on update; the `run.md` sentence
      that the block names `settings.local.json` and nothing else is corrected.
- [ ] `unattended.md` § The morning after and § A/B are rewritten for the goal branch;
      `--halt post-PR` opens the PR from it. The overlap case — two goals sharing a unit
      re-emanate it unless the first has merged — is named, and v1 keeps one live goal
      branch per checkout.
- [ ] An upgrade test or golden shows that a second run toward the same goal reports the
      first run's unit as realized. If `emanate-plan.sh` needs no change for that — the
      doctrine names the directory and the tool already reads it — the test still exists.

## Notes

**The trade, so the ticket makes it knowingly.** Today a run's output dies with its turn
branch unless a human merges it; nothing the loop built is ever the base of anything the
loop builds next. A goal branch gives that up: a promoted piece becomes the base of the next
run toward the same goal with no human between them, and a defect that clears the gate
compounds instead of dying with its branch. What buys it back is that the gate and the
drill run per piece before promote, `--reemanate` redoes a selection, the PR to the base
is still the human gate, and the whole branch is still one command to delete. The hard
ceiling — the loop never merges to the base — is unchanged.

**One accumulation branch or one per goal.** The alternative is a single long-lived
accumulation branch that every run cuts from and promotes into, which avoids re-emanating
a unit two goals share at the cost of mixing efforts in one PR. The per-goal shape is the
one this ticket specifies, because a goal is what gets accepted; the overlap is a named
limitation, not a defect.

**Why the run id moved to a trailer.** `090-emanate-turn-branch-home` chose the run id for
the path so a crashed run's leftover would say which run left it and never collide with the
next. With a goal-named path, the leftover is exactly what the next run toward that goal
wants to find, so the collision argument inverts. Phase worktrees still need the run id in
their path, for the opposite reason — see `097-emanate-stall-discard`.

**This ticket settles a path scheme a second ticket is waiting on** (recorded 2026-09-14).
`097-emanate-stall-discard` is `blocked_by` this one and cannot write its own second
criterion until § The branch scheme's **phase-worktree bullet** is decided here — its
choice is stated as "`emanate/<run-id>-<unit-slug>-<phase>`, or the goal-and-stamp form
`097-emanate-goal-branch` settles on". So the phase-worktree path is in scope here even
though every other criterion above concerns the run's own branch: leaving it for the
dependent means the dependent picks a name this ticket then rewrites.
