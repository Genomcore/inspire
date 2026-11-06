---
id: FB1-install-only-stack-skills
title: "FB1 — init installs every stack's code skills, whatever the project's stack"
created: 2026-11-05
updated: 2026-11-05
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: []
status: Open
blocked_by: []
related_to: []
---

## Origin

The maintainers of INSPIRE and of the INSPIRE Factory held the first block of a follow-up review
of the Factory on 2026-11-05. The block covered how a project enters the Factory and how it is
configured. This ticket records one of its decisions that needs work in this repository. The
review's working notes are not public, so this ticket states the decision in full.

**Decision:** a project carries only the skills it needs. Every INSPIRE methodology skill and the
cross-cutting coding skills stay. Code skills for stacks the project does not use do not,
because they add noise to the context: an API project does not need the React skills. The
ticket's first step is to check whether the mechanism already exists, and to close the ticket if
it does.

## Description

### What happens today

- `/inspire:init` runs `plugin/scripts/materialize.sh --mode init`. Its `apply_base` copies all
  of `plugin/base/skills/` into `.claude/skills/`, with no filter by stack or profile. That
  includes every stack's code skills: `android`, `angular`, `ios`, `nestjs`, `react` and
  `typescript` (`plugin/manifests/0.14.3.json`).
- The filter exists only when a skill is served: `_references/stack-skills.md` says that a skill
  with `stack` is served only to the units whose stack includes it. The INSPIRE Factory applies
  that rule to its unit agents. An attended session in the project sees every installed skill.

### What this ticket asks for

- First, check what an attended session loads. If something already limits it to the project's
  stack, close the ticket Done with no change.
- Install and update copy the code skills of the project's profiles and their language skills,
  plus every skill with no `stack`.
- A profile change installs the skills it adds and removes the ones it drops.

### Open questions

- Before the stack is chosen (no profiles yet), does init install every stack skill or none?
- Upgrade detection scores the project against each release manifest (`adr-upgrade-path.md`,
  D3). Does a project with fewer skills still score clearly?

## Acceptance criteria

- [ ] Init on an API-only project installs no React, Angular or mobile skill.
- [ ] An update keeps it that way.
- [ ] Upgrade detection still identifies the project's version.
- [ ] If an attended session is already limited to the project's stack, the ticket closes Done
      with no code change.
