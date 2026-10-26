---
id: B2-git-hooks-at-init
title: "B2 — INSPIRE's commit rules apply only to commits Claude Code makes"
created: 2026-10-26
updated: 2026-10-26
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: High
skills: []
status: Open
blocked_by: []
related_to: []
---

## Origin

The INSPIRE maintainers held the second session of a design review on 2026-10-26 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** `/inspire:init` installs the essential git hooks, so INSPIRE's commit rules
also apply to commits made outside Claude Code.

## Description

### What happens today

INSPIRE registers only Claude Code hooks. Its commit check, `pre-commit.sh`, runs the KB
review when Claude runs `git commit`. Its own header says a commit from a normal terminal
does not trigger it "by design", and that server-side enforcement "lands in CI". INSPIRE
ships no CI.

No hook stops a commit to `main`. In a test project, Claude Code committed straight to
`main` without asking. The review scripts that run on pull requests never ran.

### What this ticket asks for

- Init installs git hooks from a directory that is committed with the project. They must
  not depend on `.git/hooks`, which is not cloned.
- A guard that refuses commits on the default branch.
- A Claude Code session-start check that installs the hooks when they are missing. Git
  hooks have to be enabled in every clone, and this check removes that step.
- Init never overwrites hooks the project already has, such as husky, lefthook or a
  hand-written hook.

### Open questions

- Which hooks are "essential"? Only the protected-branch guard, or the KB review as well?
- Should init also warn when the remote's `main` is not protected? The review treated
  branch protection as the repository owner's job.
- Does `/inspire:update` install the hooks in existing projects?

## Acceptance criteria

- [ ] `/inspire:init` installs the hooks from a committed directory and leaves existing
      hooks untouched.
- [ ] A commit on the default branch is refused, from Claude Code and from a terminal.
- [ ] The session-start hook installs the hooks in a clone that lacks them.
- [ ] The open questions have written answers in this ticket's close note.
- [ ] Tests cover init, an existing hook kept as is, and the refused commit.

## Notes

- Branch protection and required approvals on the remote are repository settings, not
  INSPIRE features. The review kept them out of scope.
