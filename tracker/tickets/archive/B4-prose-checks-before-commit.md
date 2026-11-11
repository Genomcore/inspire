---
id: B4-prose-checks-before-commit
title: "B4 — prose-style findings reach the author only at pre-PR"
created: 2026-10-28
updated: 2026-10-29
reporter: "@dario.blasco"
closed_by: "@djessy.czaplicki"
closed_at: 2026-10-29
epic: roadmap
size: S
importance: Mid
skills: [domain, feature, adr, screens]
status: Done
blocked_by: []
related_to: [B2-git-hooks-at-init, F04-mech]
---

## Origin

The INSPIRE maintainers held the fourth session of a design review on 2026-10-28 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** the prose-style checks run before a commit, and through the authoring
skills, but never as a hook on each edit. A per-edit hook is slow, and fixing a finding
triggers the hook again, which can loop. Sentence length stays a soft rule, not a hard
regex limit.

## Description

### What happens today

`prose-style.sh` runs inside `review.sh`, and the only hook that runs the full review is
pre-PR. The pre-commit check runs two rules, `acyclic-deps` and `stable-blockers`, on
staged files under `04_domain` only. Among the skills, only the domain and screen review
steps run prose-style. Writing a feature, an ADR or an entity cites `writing-style.md`
and never runs it. So an author writes a whole branch before seeing a prose finding.

Sentence length is already soft. R2 warns over 35 words, and every prose-style rule
except R4 is a warning. An earlier 25-word cap was dropped after it caused friction:
95% of its hits needed only a few more words. The review kept it that way. The aim is
one idea per sentence, not four paragraphs for one idea, and a hard limit fights it.

### What this ticket asks for

- The pre-commit check runs the per-file KB rules, `prose-style.sh` among them, on the
  staged KB files of every layer, not just `04_domain`.
- Prose warnings are reported at commit time and never block it. Errors block as they do
  today.
- The authoring skills run the mechanical checks on the file they just wrote, the way
  they already run `trust.sh stamp`. This criterion moved here from
  `0911-file-scope-silent-pass`.
- No hook runs on each edit. The ticket states why, so nobody adds one later.

### Open questions

- When a Claude Code hook lets a command through, the agent does not see the hook's
  output. How does a warning reach the agent without blocking the commit?
- The skills already cite the writing rules, and agents ignore them anyway. Do the
  skills need to restate the rules as commands, or is a mechanical check at commit
  enough? "Enough as is" is a valid answer.

## Acceptance criteria

- [ ] A commit that stages KB files in any layer gets the per-file KB rules' findings on
      those files, prose-style included.
- [ ] Prose-style warnings never block a commit, and the author or agent sees them.
- [ ] The authoring skills run the mechanical checks on each file they write, and act on
      the findings.
- [ ] No INSPIRE hook runs on each file edit, and the reason is written where a future
      maintainer would add one.
- [ ] Tests cover the pre-commit check on a staged file outside `04_domain`.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- Was `blocked_by: 0911-file-scope-silent-pass`: checking a staged file, or the file a
  skill just wrote, needs a single file to be a valid scope. 0.14.2 made it one.
- `B2-git-hooks-at-init` installs git hooks. When it lands, the git pre-commit runs the
  same checks as the Claude Code one, so a commit from a terminal is checked too.
- `F04-mech` carries five fixes to what the prose-style rules find. This ticket changes
  when they run. Neither waits for the other.
- No Factory port. This changes attended sessions only.

## Resolution

Shipped on `release/0.15.0`. The check runs right after the commit instead of right
before it, and the reason is the first open question.

- **After each commit, a KB review of the committed files.** `dispatch.sh` is now
  registered on PostToolUse for Bash as well, and routes `git commit` there to
  `post-commit.sh`. It runs `review.sh <file>` on each KB file the new commit
  contains, in every layer, and reports every finding on those files (prose style
  included) by exiting 2. On PostToolUse that sends stderr to the agent and undoes
  nothing. Deleted files are skipped, and a commit with no KB file reports nothing.
- **Errors block as they did.** `pre-commit.sh` is unchanged: before the commit, it
  still blocks on the two domain graph rules for the staged modules. The new review
  reports errors without blocking, and errors still block the pull request. Turning
  more rules into commit blockers would be a separate decision.
- **The four authoring skills check each write.** `/inspire-domain`,
  `/inspire-feature`, `/inspire-adr` and `/inspire-screens` run `review.sh <file>`
  after each write, fix the findings, and then stamp. They are the four skills whose
  layers the rules cover. `_references/write-checks.md` says what to fix now (errors,
  and warnings about the file's own text) and what to tell the operator about instead
  (warnings that wait on another artifact, and warnings the operator keeps).
- **No per-edit hook.** The reason is written in `AGENTS.md`, next to where hooks are
  registered, and in `write-checks.md`.
- **Tests.** `plugin/test/hooks/01-post-commit.sh` drives `dispatch.sh` the way Claude
  Code does. It checks that a committed feature (outside `04_domain`) gets its
  `sections-present` error and its R2 and R6 prose warnings, that a file the commit does
  not contain is not reported, and that PreToolUse never runs the review. 7 of its 14
  assertions fail with the old dispatcher. `materialize/01-init-current-tree.sh` checks
  the PostToolUse registration and that a second init does not duplicate it. The
  criterion asked for tests of a *pre*-commit check; the check moved after the commit,
  so the tests did too.

### Answers to the open questions

- **How does a warning reach the agent without blocking the commit?** Through a
  PostToolUse hook that exits 2. The hooks reference
  (code.claude.com/docs/en/hooks) says PreToolUse stdout and stderr on exit 0 never
  reach Claude. The one PreToolUse way to pass text while letting the command through
  is `additionalContext` together with `permissionDecision: "allow"`, and `allow`
  skips the operator's permission prompt for that command. A response that adds
  context without a decision is not documented. PostToolUse exit 2 is documented as
  "Shows stderr to Claude; the tool already ran", which is exactly a report that
  cannot block.
- **Do the skills need to restate the rules as commands?** No. The skills already
  cite the writing rules, and agents skip prose they are only pointed at. What
  changes behaviour is a finding about the file in front of them, so each skill now
  runs the checker and acts on its output, and `writing-style.md` stays the one
  place the rules live.
