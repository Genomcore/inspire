---
id: B5-react-skill-from-the-team
title: "B5 — the React stack skill defers its own rules"
created: 2026-10-30
updated: 2026-10-30
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: High
skills: [code]
status: Open
blocked_by: []
related_to: [F07-gates]
---

## Origin

The INSPIRE maintainers held the fifth and last session of a design review on 2026-10-29
while preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** bring the React skills that the development team has curated into INSPIRE,
so front-end code gets the reviews it should. The skills that tell an agent how to code
are one set. The same skills apply when a person codes by hand, in a spike, and in an
INSPIRE Factory run.

## Description

### What happens today

`inspire-code-react` (0.13.0) has a layering section and one reference file,
`references/testing.md`. Its `## Module boundaries` and `## Quality gates` sections both
say "not yet formulated for this stack", so it declares no `gates:`. For comparison,
`inspire-code-nestjs` has five reference files and `inspire-code-angular` has thirteen.
A React unit is coded and reviewed against layering and tests only.

The team's own React skills live outside INSPIRE, and the tool that exported them has
not been updated in weeks. The INSPIRE Factory already reads the skills materialized in
the project, so what INSPIRE ships is what the Factory uses. The gap is the content, not
the plumbing.

### What this ticket asks for

- The team's React rules move into `inspire-code-react`, following the stack-skill
  contract (`_references/stack-skills.md`): module boundaries, quality gates with their
  `gates:` frontmatter, and the detailed material under `references/`.
- `_references/quality-gates.md` Rule 2 forbids adopting gates nobody has tested. The
  team's rules were used on real React code. The ticket either records that as the
  iteration the skill's deferral asks for, or runs the bench on them first.
- Rules that belong to one product stay in that project, as its own skills with
  `stack: react`.
- The ticket names where the canonical copy lives, so no rule is kept in two places.

### Open questions

- Who owns the canonical copy? Either INSPIRE ships it and the team contributes by pull
  request, or the team's repository owns it and INSPIRE syncs from it. The second is the
  "external profile source" that `F07-gates` dropped on 2026-10-28 until it was clear
  who owns stack rules.
- Does the MUST/SHOULD wording go through the bench, as it did for NestJS in 0.13.0?

## Acceptance criteria

- [ ] `inspire-code-react` states its module boundaries and quality gates, with
      `gates:` frontmatter, and no longer carries a deferral for either.
- [ ] The adopted gates are either backed by a recorded iteration on real code or by a
      bench run, as `quality-gates.md` Rule 2 requires.
- [ ] The canonical home of the React rules is named in this ticket's close note.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- No Factory port. The INSPIRE Factory reads the project's skills.
- If the canonical copy lives in the team's repository, the external-source criterion
  that `F07-gates` dropped comes back here, not in F07.
