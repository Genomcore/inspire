---
id: 097-emanate-stall-discard
title: "097 — emanate: a stalled phase's worktree cannot be discarded, and the next run collides with it"
created: 2026-09-10
updated: 2026-09-14
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: High
skills: [code]
status: Open
blocked_by: []
related_to: []
---

## Description

`run.md` § Stall, cascade and autopsy: *"The stalled phase's worktree is discarded without
harvesting; what is left to inspect is whatever earlier phases already harvested onto the
unit's integration branch."* It gives the reason too: *"the worktree path carries no run id,
so a surviving worktree would collide with the next run of the same unit — and the next run
would then be building on a tree nobody vouched for."*

In the second field run (`20260910-081400-pocm`, `gs`, 2026-09-10) two units stalled at
their contracter gate. The orchestrator issued `git worktree remove --force` and the
harness safety net blocked it — rule `git.worktree-remove-force`, *"can delete uncommitted
changes"*. Plain `git worktree remove` refuses a tree with modified or untracked files, and
a contracter's worktree always has both. Both worktrees stayed on disk with the rejected
emissions inside; the report said so and left the decision to the operator, whose ruling
is that a rejected emission is not harvested: if it failed, it failed.

The doctrine names an outcome and no git form that produces it, and the only form that
produces it is destructive. `unattended.md` § Permission posture does not list it among
the things auto mode does not cover. The consequence is the one the section itself
predicts: the re-run the report recommends fails at `prepare` for `workspace.role`, because
`.claude/worktrees/emanate-workspace-role-contracter` exists.

## Acceptance criteria

- [ ] § Stall names the discard form, and it is **non-destructive by construction**: the
      stalled phase's whole tree is committed onto the unit's integration branch as one
      commit labelled as an autopsy — unfiltered by the owned pathspec, so it is never a
      harvest, and on a branch that is never promoted — and the now-clean worktree is
      removed with plain `git worktree remove`. The autopsy commit's message says which
      phase stalled and why.
- [ ] Phase worktree paths carry the run id — `.claude/worktrees/emanate-<run-id>-<unit-slug>-<phase>`,
      or the goal-and-stamp form `097-emanate-goal-branch` settles on — so a leftover from
      a crashed run never blocks the next run of the same unit, and the closing block lists
      every worktree the run leaves on disk.
- [ ] `unattended.md` § Permission posture states that the loop never depends on a
      destructive git form (`worktree remove --force`, `clean -fd`, `branch -D`) to make
      progress, because the harness may refuse any of them.
- [ ] **Or Done with zero code changed**, if the ruling is that an autopsy commit puts
      rejected code into git history where the operator does not want it and the honest
      answer is a permitted destructive form — then that form, and where it is permitted,
      is the deliverable, in § Stall and § Permission posture.

## Notes

**Why `blocked_by: [097-emanate-goal-branch]`** (recorded 2026-09-14). The second
criterion cannot be *written* until that ticket settles the path scheme — it already says
so in its own words, "or the goal-and-stamp form `097-emanate-goal-branch` settles on".
The dependency is hard in both directions a hard dependency can be: this ticket's premise
is a property of the branch scheme (§ Stall's justification quotes "the worktree path
carries no run id", which stops being true the moment the goal branch lands), and its
deliverable is a bullet in the same list — `run.md` § The branch scheme's phase-worktree
bullet, and § Permission posture in `unattended.md`, are edited by both.

**`blocked_by` cleared 2026-09-14.** `097-emanate-goal-branch` closed against its eight
criteria, and the path it settled is
`.claude/worktrees/emanate-<goal-slug>-<unit-slug>-<run-stamp>-<phase>` — the run stamp is
in the path, so the second criterion's collision is gone by construction and the work left
here is the discard form.

**The first criterion is superseded by the operator's ruling** (2026-09-14): a stalled
phase's worktree is **kept**, and nothing it holds is committed anywhere. An autopsy commit
would put work no overseer approved and no gate judged into the history the operator reads;
the proof of a phase that could not finish is the directory it left, not a commit. So the
deliverable is the opposite of a discard form — § Stall now runs no removal at all, and
"the autopsy is the branch, **and** the worktree".

**The fourth criterion's fork resolves to neither of its two branches.** It offered an
autopsy commit or a permitted destructive form; the answer is a third thing, keeping the
tree, which needs no commit and no removal. Phase 1 is what makes it free: the run stamp in
the path means a kept worktree never blocks the next run of the same unit.

**The third criterion is satisfied without changing `emanate-harvest.sh`.** Its `--discard`
still runs `git worktree remove --force`, and that is not a dependency: it fires only on a
phase whose owned paths are already on the integration branch and whose remaining content
was dropped on purpose, so a harness refusal costs a directory the run report names rather
than a wave. `--force` inside the script was never what the field run hit — a hook reads the
Bash command it was given, not what a script runs in a subprocess; the two blocked calls were
the orchestrator's own, for the two stalled worktrees, and under this ruling those worktrees
should have been kept anyway.

The two stalled worktrees in the `gs` checkout are the operator's to delete by hand, and the
report names them — which is now the designed outcome rather than a leftover.
