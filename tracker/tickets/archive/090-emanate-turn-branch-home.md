---
id: 090-emanate-turn-branch-home
title: "090 — emanate: the turn branch has no stated home, so the operator's checkout became it"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-09-09
epic: follow-up
size: S
importance: Mid
skills: [code]
status: Done
blocked_by: []
related_to: [090-emanate-turn-liveness]
---

## Description

`run.md` § The branch scheme says the turn branch is "cut from the branch the run was
launched on" and that phase worktrees are detached at each integration branch's tip. It
does not say where the **turn branch itself** is checked out while the run lives — and
promote needs it checked out somewhere, because a merge commit with trailers cannot be
made against a bare ref.

The first field run answered the question by default: the reflog of the `gs` project
shows `checkout: moving from main to emanate/20260908-102102-qcpd` at 10:21 UTC in the
operator's own working tree, and the tree was still on that branch a day later. The run
never reached promote, so nothing was merged there, but the operator's checkout had
silently become run state — the shape the branch scheme's "one live run per checkout"
assumption warns about without naming.

## Acceptance criteria

- [x] § The branch scheme states where the turn branch is checked out during a run:
      either a dedicated worktree under the house convention
      (`.claude/worktrees/emanate-turn`, discarded at the run's end), or explicitly the
      launching checkout — in which case the doctrine says so and requires restoration.
- [x] A run **ends with the operator's checkout on the branch it was launched from**,
      whichever home is chosen. The closing block of the run report names the turn branch
      and that the checkout was restored.
- [x] `unattended.md` § The morning after is checked against the choice: "delete the turn
      branch" must not be a command the operator runs while standing on it.
- [ ] **Or Done with zero code changed**, if the ruling is that the launching checkout is
      the intended home and only the restoration sentence was missing — then that
      sentence is the deliverable.

## Resolution

**The first option: a worktree of the run's own**, `.claude/worktrees/emanate-<run-id>`,
cut with the branch in one `git worktree add -b` and removed at the run's end,
immediately before the closing block is written — which is what lets that block report
whether the removal happened. The branch outlives the worktree; promote merges there.

The name carries the **run id** rather than the ticket's `emanate-turn`, and the
difference is not cosmetic: a fixed path makes the *next* run fail on a directory a
crashed one left behind, while a run-id path never collides and says which run left it.
Phase worktrees already embed the unit slug for the same reason.

**Criterion 2 is met by construction rather than by restoring anything**, and the report
says what happened rather than a word for what did not: the closing block gains **where
the work is** — the turn branch, whether its worktree survives, and that the launch
checkout was never moved. There is no restoration step to get wrong, and nothing to
restore after a crash.

`unattended.md` § The morning after now carries the reason "delete the turn branch" is a
command an operator can run: nobody is standing on it. § promote states that the merge
runs in that worktree and never in the launch checkout.

**The zero-change exit stays unticked.** It would have ratified the launching checkout as
the home and asked for a restoration sentence. Restoration narrows the window and never
closes it — between t=0 and the exit the operator's tree still stands on a branch nothing
has vouched for, and a run that dies mid-wave restores nothing at all. The same rule that
detaches every phase worktree answers this one.

## Notes

Detached worktrees per phase are already the rule for personas, for exactly the reason
this ticket exists: two worktrees cannot check out one branch, and the thing nobody
vouched for should never be the operator's tree.
