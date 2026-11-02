---
id: B1-decisions-in-context
title: "B1 — a session starts without the project's decisions in context"
created: 2026-10-23
updated: 2026-10-30
reporter: "@dario.blasco"
closed_by: "@djessy.czaplicki"
closed_at: 2026-10-30
epic: roadmap
size: M
importance: High
skills: [adr, code]
status: Done
blocked_by: []
related_to: [B1-adr-decision-rationale]
---

## Origin

The INSPIRE maintainers held a design review on 2026-10-23 while preparing the training of
new INSPIRE operators. This ticket records one of its decisions. The review's working notes
are not public, so this ticket states everything needed to act on the decision.

**Decision:** every INSPIRE session, for specification or for code, starts with all of
the project's live decisions in context. ADRs are the main guardrails on what may be
built and how.

## Description

Today a session sees an ADR only when a skill reads it on purpose. `inspire-code`
re-reads the ADRs that specify the unit it is building. A specification session, or a
code session working outside a unit, can contradict a decision it never loaded.

`plugin/base/hooks/session-start.sh` already injects context into every session: the
project's `output_language` and the writing contract. The proposal is to add a **decision
digest** there: every live decision, as its binding statement only.

Questions the design answers:

- **What goes in.** Only live decisions; superseded and rejected ADRs are left out. The
  design also decides whether decisions at `design` maturity are included or flagged.
- **Size.** The digest grows with the project. It needs a size budget, and a rule for
  what happens past it: truncate, scope, or link. A digest built from the decision files
  that `B1-adr-decision-rationale` introduces stays small. One built from whole ADRs
  does not.
- **Scope.** Whether an ADR's `surfaces:` field narrows the digest for a session working
  on one surface.
- **The emanation process.** Emanation, the unattended KB-to-code loop, runs agents
  outside the attended session. How those agents receive the digest is up to the
  INSPIRE Factory, the separate service that runs emanation. INSPIRE's part is a digest
  the emanation process can read, produced by the same script the hook uses.

## Acceptance criteria

- [x] Every attended session in a materialized project starts with the decision digest
      in context.
- [x] The digest is also available as a script's output, so the emanation process can
      consume it.
- [x] The digest has a stated size budget and a stated rule for going over it.
- [x] A project with no ADRs gets no digest and pays no cost.
- [x] The digest is built mechanically by a script under `plugin/base/bin/` (materialized
      as `.inspire/bin/`), never by a model summarizing ADRs. A golden fixture pins its
      output.

## Resolution

`plugin/base/bin/decisions.sh` builds the digest, and `session-start.sh` injects it
after the rest of the session context. The design questions have these answers:

- **What goes in.** Every ADR that is neither superseded nor rejected, as one entry:
  id, maturity, surfaces, title, then its `## Decision` text verbatim, HTML comments
  removed. `design` and `prototyped` decisions go in with their maturity in the entry,
  and the digest's head says they can still be refined while an `implemented` one is
  only superseded. A single-file ADR contributes its `## Decision` alone; a rationale
  file never appears.
- **Size.** The hook passes `--budget 6000` (characters). Over it, the digest becomes
  an index: one line per decision with its id, maturity, surfaces and title, and a
  pointer to the script for the full text. When even the index is over, it is cut,
  and its last line counts what it left out. The script alone has no budget.
- **Scope.** The hook cannot know which surface a session will work on, so it injects
  every live decision, each labelled with the surfaces it binds. `--surface <id>`
  narrows the script's output to the ADRs that bind that surface: those listing it,
  those listing `all`, and those listing none.
- **The emanation process.** The same script, run from the project root, is what a
  process running agents outside a session reads. The Factory's half is filed in its
  own tracker once this lands.

The output is pinned in full by `plugin/base/bin/test/test-decisions.sh`, and
`plugin/test/hooks/02-session-start-decisions.sh` covers the hook: the digest arrives,
a project with no live ADR and an install without the script get none, and a digest
over budget is injected as an index within 6,000 characters.

## Notes

- This ticket does not depend on `B1-adr-decision-rationale`. It can read each ADR's
  `## Decision` section today. The split makes the digest shorter and its source
  cleaner, which is why the two are related.
- **Factory consumer (2026-10-28 tracker pass).** The emanation half of the digest is
  the INSPIRE Factory's: its unit agents receive the digest only if the Factory passes
  it on. That work is filed in the Factory's tracker once the digest script ships here.
