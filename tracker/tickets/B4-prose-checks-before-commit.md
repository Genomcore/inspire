---
id: B4-prose-checks-before-commit
title: "B4 — prose-style findings reach the author only at pre-PR"
created: 2026-10-28
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: S
importance: Mid
skills: [domain, feature, adr, screens]
status: Open
blocked_by: [0911-file-scope-silent-pass]
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

- `blocked_by: 0911-file-scope-silent-pass`: checking a staged file, or the file a skill
  just wrote, needs a single file to be a valid scope.
- `B2-git-hooks-at-init` installs git hooks. When it lands, the git pre-commit runs the
  same checks as the Claude Code one, so a commit from a terminal is checked too.
- `F04-mech` carries five fixes to what the prose-style rules find. This ticket changes
  when they run. Neither waits for the other.
- No Factory port. This changes attended sessions only.
