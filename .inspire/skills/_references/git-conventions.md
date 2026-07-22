# Git conventions (shared reference)

Sensible, stack-agnostic defaults for branches, commits, and PRs, plus the safety
protocol every skill that touches git follows. **Project-specific specifics — the
base-branch name, the ticket system, the trailer policy, protected branches — live
in the project's `CLAUDE.md` and override these defaults.** When the two disagree,
the project wins.

## Branches

- Branch off the project's **base branch** (commonly `main`, or a
  `develop`/`preproduction` integration line where the project uses one). Create
  from an up-to-date local base.
- Name by kind + short hyphenated summary: `feature/…`, `bugfix/…`, `hotfix/…`.
  Where the project tracks work in tickets, include the id
  (`feature/{ticket}_{summary}`) — in INSPIRE that is a `TASK-{id}`
  ([`/inspire_task`](../inspire-task/SKILL.md)) or the project's
  external tracker id. Never invent a ticket id.
- A branch's upstream should be its **own** remote counterpart
  (`origin/<branch>`), not the base it was cut from — otherwise status counters
  report phantom "ahead" commits. Fix a mis-set upstream with
  `git branch --set-upstream-to=origin/<branch>`.

## Commits — Conventional Commits

```
<type>[(<scope>)]: <description>
```

- **type** — `feat` · `fix` · `refactor` · `docs` · `test` · `chore` · `style` ·
  `perf` · `ci` · `build`. Pick the most accurate.
- **scope** (optional) — lowercase subsystem/layer (`auth`, `users`, `dto`).
- **description** — imperative, lowercase first word (proper nouns keep their
  case), ≤72 chars.
- **body** (optional, encouraged when it helps) — blank line after the subject,
  then bullets for each distinct change.
- **breaking change** — append `!` before the colon (`feat!:`) and add a
  `BREAKING CHANGE: <what>` footer.
- **ticket / trailer policy is the project's.** If the project prefixes commits
  with a ticket id or requires (or forbids) `Co-Authored-By`/other trailers, follow
  the project's `CLAUDE.md` and the harness's own commit rules — this reference does
  not mandate a trailer either way.
- **Group related changes; split unrelated ones** into separate commits. If truly
  entangled, list each as a body bullet — never bury them under a vague subject.

## Pull requests

- Target the **base branch** the work was cut from. A stacked/subtask branch targets
  its **parent** branch, not the base.
- Keep the PR scoped to one coherent change.

## Merge-conflict resolution

When you merge the base into a feature branch and hit conflicts, the **merge commit**
is the only place carrying bytes no PR review saw (your hand-resolution). Make it
auditable:

- **Keep it a pure merge commit** — resolve the conflicts and nothing else. No
  reformat, no opportunistic refactor; anything extra hides inside the merge.
- **Never** commit with conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) left in.
  Build / type-check / lint after resolving, before committing.
- **Document the resolution in the merge body**: each conflicted file and how it was
  resolved (took theirs / ours / combined, and what was combined).
- Reviewers inspect only the resolution: `git show --cc <merge-sha>` shows just the
  hand-resolved hunks. Do not squash the merge into the feature work, and never
  rebase a branch already pushed/shared.

## Safety protocol

- **NEVER** commit on your own initiative. A commit requires an explicit, recent user
  request. Finishing a task, passing tests, or "saving progress" do **not** count.
- **NEVER** push, force-push, or rewrite the history of pushed commits (no `--amend`
  / rebase on published branches). The user triggers pushes.
- **NEVER** stage blindly (`git add -A` / `git add .`). Stage by explicit path or
  with `-p`; if the staged set mixes unrelated concerns, split it.
- **NEVER** skip hooks (`--no-verify`). If a hook fails, fix the cause and commit
  again — INSPIRE's `pre-commit` / `pre-pr` hooks are part of the gate.
- **NEVER** update git config or change a protected branch's settings silently.
- **NEVER** commit secrets (`.env`, credentials, private keys, tokens).
